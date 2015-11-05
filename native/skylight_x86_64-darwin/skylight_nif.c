#include <string.h>
#include "erl_nif.h"
#include "skylight_dlopen.h"

#include <stdio.h>

// Global atoms to be used throughout the functions.
ERL_NIF_TERM atom_ok;
ERL_NIF_TERM atom_already_loaded;
ERL_NIF_TERM atom_error;
ERL_NIF_TERM atom_loading_failed;

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
  return 0;
}

// Wraps sky_load_libskylight().
static ERL_NIF_TERM load_libskylight(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[]) {
  ErlNifBinary path_bin;

  if (argc != 1 || !enif_is_binary(env,argv[0])) {
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

// Wraps sky_lex_sql().
static ERL_NIF_TERM lex_sql(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[]) {
  ErlNifBinary sql_bin;
  enif_inspect_binary(env, argv[0], &sql_bin);

  sky_buf_t sql;
  sky_buf_t title;
  sky_buf_t statement;
  uint8_t title_store[128];

  sql = (sky_buf_t) {
    .data = sql_bin.data,
    .len = sql_bin.size,
  };

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
    return enif_raise_exception(env, enif_make_string(env, "lex_sql failed", ERL_NIF_LATIN1));
  }

  ErlNifBinary statement_bin;
  enif_alloc_binary(statement.len, &statement_bin);
  memcpy(statement_bin.data, statement.data, statement.len);
  return enif_make_binary(env, &statement_bin);
}


// List of functions to define in the module that loads this NIF file.
static ErlNifFunc nif_funcs[] = {
  {"load_libskylight" , 1, load_libskylight},
  {"hrtime"           , 0, hrtime},
  {"lex_sql"          , 1, lex_sql}
};


// Where the magic happens.
// Defines the NIFs listed in `nif_funcs` in the module passed as the first
// argument to this macro. The last four arguments are load/unload/reload hooks
// called by Erlang.
ERL_NIF_INIT(Elixir.Skylight.NIF, nif_funcs, &load, NULL, NULL, NULL);
