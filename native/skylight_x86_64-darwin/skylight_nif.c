#include <string.h>
#include "erl_nif.h"
#include "skylight_dlopen.h"

#include <stdio.h>

// Bunch of macros.

// Raises an Erlang exception with `msg` as the reason (as an Erlang char list).
#define ERL_RAISE(msg) return enif_raise_exception(env, enif_make_string(env, (msg), ERL_NIF_LATIN1))

// Converts an Erlang binary (`bin`) to a `sky_buf_t` buffer struct.
#define BINARY_TO_BUF(bin)                      \
  (sky_buf_t) {                                 \
    .data = bin.data,                           \
    .len = bin.size,                            \
  }

// Global atoms to be used throughout the functions.
ERL_NIF_TERM atom_ok;
ERL_NIF_TERM atom_already_loaded;
ERL_NIF_TERM atom_error;
ERL_NIF_TERM atom_loading_failed;

// Resource type for Skylight instrumenters. It's initialized in the `load`
// function.
ErlNifResourceType *INSTRUMENTER_RES_TYPE;

// Destructor for `INSTRUMENTER_RES_TYPE` resources.
void instrumenter_res_destructor(ErlNifEnv *env, void *obj) {
  printf("Instrumenter resource being destroyed!\n");
}

// Load hook. Called by Erlang when this NIF library is loaded and there is no
// previously loaded library for this module. Must return 0 for the loading not
// to fail.
//
// This function just creates a bunch of atoms in the VM.
int load(ErlNifEnv *env, void **priv_data, ERL_NIF_TERM load_info) {
  atom_ok = enif_make_atom(env, "ok");
  atom_already_loaded = enif_make_atom(env, "already_loaded");
  atom_error = enif_make_atom(env, "error");
  atom_loading_failed = enif_make_atom(env, "loading_failed");

  // Open the resource type for the instrumenter.
  INSTRUMENTER_RES_TYPE = enif_open_resource_type(env,
                                                  "Elixir.Skylight.NIF",
                                                  "instrumenter",
                                                  instrumenter_res_destructor,
                                                  ERL_NIF_RT_CREATE | ERL_NIF_RT_TAKEOVER,
                                                  NULL);
  return 0;
}

// Wraps sky_load_libskylight().
static ERL_NIF_TERM load_libskylight(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[]) {
  ErlNifBinary path_bin;

  if (argc != 1 || !enif_is_binary(env, argv[0])) {
    return enif_make_badarg(env);
  }

  // Return early if the lib was already loaded.
  if (sky_hrtime != NULL) {
    return atom_already_loaded;
  }

  // Here, we're sure argv[0] is a binary because we checked at the top of this
  // function.
  enif_inspect_binary(env, argv[0], &path_bin);

  const unsigned char *path = path_bin.data;
  int loading_result = sky_load_libskylight((char *) path);

  if (loading_result < 0) {
    // {error, loading_failed}
    return enif_make_tuple2(env, atom_error, atom_loading_failed);
  } else {
    return atom_ok;
  }
}

// Wraps sky_hrtime().
static ERL_NIF_TERM hrtime(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[]) {
  uint64_t hrtime = sky_hrtime();
  return enif_make_uint64(env, (ErlNifUInt64) hrtime);
}

// Wraps sky_instrumenter_new().
//
// The `env` array passed as the first argument to sky_instrumenter_new() is an
// array of env variables and values that looks like this:
//
//     [<<"SKYLIGHT_VERSION">>, <<"0.8.1">>,
//      <<"SKYLIGHT_LAZY_START">>, <<"true">>]
//
static ERL_NIF_TERM instrumenter_new(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[]) {
  ERL_NIF_TERM erl_env = argv[0];
  sky_buf_t sky_env[256];

  // Get the length of the env list.
  unsigned int envc;
  enif_get_list_length(env, erl_env, &envc);

  // The Ruby extension raises if the env array has more than 256 elements, so
  // let's do the same.
  if (envc >= 256) {
    ERL_RAISE("env array has more than 256 elements");
  }

  ERL_NIF_TERM head;
  ERL_NIF_TERM tail = erl_env;
  ErlNifBinary current_bin;

  for (int i = 0; i < envc; i++) {
    // Replace `head` with the current element and `tail` with the new tail to
    // reuse in the next iteration.
    enif_get_list_cell(env, tail, &head, &tail);
    enif_inspect_binary(env, head, &current_bin);
    sky_env[i] = BINARY_TO_BUF(current_bin);
  }

  // Let's load the instrumenter into the `instrumenter` variable.
  sky_instrumenter_t *instrumenter;
  sky_instrumenter_new(sky_env, (int) envc, &instrumenter);

  sky_instrumenter_t **resource =
    enif_alloc_resource(INSTRUMENTER_RES_TYPE, sizeof(sky_instrumenter_t *));

  memcpy((void *) resource, (void *) &instrumenter, sizeof(sky_instrumenter_t *));

  ERL_NIF_TERM term = enif_make_resource(env, resource);

  // Not sure if this is necessary yet:
  // enif_release_resource(resource);

  return term;
}

// Wraps sky_instrumenter_start().
static ERL_NIF_TERM instrumenter_start(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[]) {
  const sky_instrumenter_t **resource;
  enif_get_resource(env, argv[0], INSTRUMENTER_RES_TYPE, (void *) &resource);

  const sky_instrumenter_t *instrumenter = *resource;

  int res = sky_instrumenter_start(instrumenter);
  return (res == 0) ? atom_ok : atom_error;
}

// Wraps sky_lex_sql().
static ERL_NIF_TERM lex_sql(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[]) {
  ErlNifBinary sql_bin;
  enif_inspect_binary(env, argv[0], &sql_bin);

  sky_buf_t sql;
  sky_buf_t title;
  sky_buf_t statement;
  uint8_t title_store[128];

  sql = BINARY_TO_BUF(sql_bin);

  title = (sky_buf_t) {
    .data = title_store,
    .len = sizeof(title_store),
  };

  statement = (sky_buf_t) {
    .data = malloc(sizeof(char) * sql.len),
    .len = sql.len,
  };

  int res = sky_lex_sql(sql, &title, &statement);

  if (res < 0) {
    ERL_RAISE("lex_sql failed");
  }

  ErlNifBinary statement_bin;
  enif_alloc_binary(statement.len, &statement_bin);
  memcpy(statement_bin.data, statement.data, statement.len);
  return enif_make_binary(env, &statement_bin);
}


// List of functions to define in the module that loads this NIF file.
static ErlNifFunc nif_funcs[] = {
  {"load_libskylight", 1, load_libskylight},
  {"hrtime"          , 0, hrtime},
  {"instrumenter_new", 1, instrumenter_new},
  {"instrumenter_start", 1, instrumenter_start},
  {"lex_sql"         , 1, lex_sql}
};


// Where the magic happens.
// Defines the NIFs listed in `nif_funcs` in the module passed as the first
// argument to this macro. The last four arguments are load/unload/reload hooks
// called by Erlang.
ERL_NIF_INIT(Elixir.Skylight.NIF, nif_funcs, &load, NULL, NULL, NULL);
