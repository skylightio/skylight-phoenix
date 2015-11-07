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

// Converts a `sky_buf_t` buffer to an Erlang binary (`ErlNifBinary`) struct.
#define BUF_TO_BINARY(buf) \
  (ErlNifBinary) {         \
    .data = buf.data,      \
    .size = buf.len,       \
  }

// Returns `ok` if `res` is 0 (success), `error` otherwise.
#define FFI_RESULT(res) ((res) == 0) ? atom_ok : atom_error

// Raises if the native function returns non-0.
#define MAYBE_RAISE_FFI(ffi_call)                 \
  if ((ffi_call) != 0) {                          \
    ERL_RAISE("call to native function failed");  \
  }

// Helper functions headers.
void get_instrumenter(ErlNifEnv *, ERL_NIF_TERM, sky_instrumenter_t **);
void get_trace(ErlNifEnv *, ERL_NIF_TERM, sky_trace_t **);

// Global atoms to be used throughout the functions.
ERL_NIF_TERM atom_ok;
ERL_NIF_TERM atom_loaded;
ERL_NIF_TERM atom_already_loaded;
ERL_NIF_TERM atom_error;

// Resource type for Skylight instrumenters. It's initialized in the `load`
// function.
ErlNifResourceType *INSTRUMENTER_RES_TYPE;

// Resource type for Skylight traces. Initialized in the `load` function.
ErlNifResourceType *TRACE_RES_TYPE;

// Destructor for `INSTRUMENTER_RES_TYPE` resources.
void instrumenter_res_destructor(ErlNifEnv *env, void *obj) {
  printf("Instrumenter resource being destroyed!\n");
}

// Destructor for `TRACE_RES_TYPE` resources.
void trace_res_destructor(ErlNifEnv *env, void *obj) {
  printf("Trace resource being destroyed!\n");
}

// Load hook. Called by Erlang when this NIF library is loaded and there is no
// previously loaded library for this module. Must return 0 for the loading not
// to fail.
//
// This function just creates a bunch of atoms in the VM.
int load(ErlNifEnv *env, void **priv_data, ERL_NIF_TERM load_info) {
  atom_ok = enif_make_atom(env, "ok");
  atom_loaded = enif_make_atom(env, "loaded");
  atom_already_loaded = enif_make_atom(env, "already_loaded");
  atom_error = enif_make_atom(env, "error");

  // Open the resource types for the instrumenter and trace.
  INSTRUMENTER_RES_TYPE = enif_open_resource_type(env,
                                                  "Elixir.Skylight.NIF",
                                                  "instrumenter",
                                                  instrumenter_res_destructor,
                                                  ERL_NIF_RT_CREATE | ERL_NIF_RT_TAKEOVER,
                                                  NULL);
  TRACE_RES_TYPE = enif_open_resource_type(env,
                                           "Elixir.Skylight.NIF",
                                           "trace",
                                           trace_res_destructor,
                                           ERL_NIF_RT_CREATE | ERL_NIF_RT_TAKEOVER,
                                           NULL);

  return 0;
}

// Wraps:
//   int sky_load_libskylight(const char* filename);
// from skylight_dlopen.c.
static ERL_NIF_TERM load_libskylight(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[]) {
  // Return early if the lib was already loaded (we're checking for the
  // existence of the sky_hrtime function here).
  if (sky_hrtime != 0) {
    return enif_make_tuple2(env, atom_ok, atom_already_loaded);
  }

  ErlNifBinary path_bin;
  enif_inspect_binary(env, argv[0], &path_bin);

  // Let's null-terminate the given binary by allocating the given binary's size
  // + 1 bytes, filling them in with the binary and then filling the last byte
  // with a 0 byte.
  char *path = malloc(sizeof(char) * (path_bin.size + 1));
  memcpy(path, path_bin.data, sizeof(char) * (path_bin.size + 1));
  path[path_bin.size] = '\0';

  int res = sky_load_libskylight((const char *) path);

  if (res != 0) {
    return atom_error;
  } else {
    return enif_make_tuple2(env, atom_ok, atom_loaded);
  }
}

// Wraps:
//   uint64_t sky_hrtime();
// in
//   hrtime() :: integer
static ERL_NIF_TERM hrtime(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[]) {
  uint64_t hrtime = sky_hrtime();
  return enif_make_uint64(env, (ErlNifUInt64) hrtime);
}

// Wraps:
//   int sky_instrumenter_new(sky_buf_t* env, int envc, sky_instrumenter_t** out);
// in:
//   instrumenter_new(env :: [binary]) :: <resource>
//
// The `env` array passed as the first argument to sky_instrumenter_new() is an
// array of env variables and values that looks like this:
//
//     ["SKYLIGHT_VERSION", "0.8.1",
//      "SKYLIGHT_LAZY_START", "true"]
//
static ERL_NIF_TERM instrumenter_new(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[]) {
  ERL_NIF_TERM erl_env = argv[0];
  sky_buf_t sky_env[256];

  // Get the length of the erl_env list passed as the argument to the NIF.
  unsigned int envc;
  enif_get_list_length(env, erl_env, &envc);

  // The Ruby extension raises if the env array has more than 256 elements, so
  // let's do the same.
  if (envc >= 256) {
    ERL_RAISE("env array has more than 256 elements");
  }

  ERL_NIF_TERM head;
  ERL_NIF_TERM tail = erl_env;

  for (int i = 0; i < envc; i++) {
    ErlNifBinary current_bin;

    // Replace `head` with the current element and `tail` with the new tail to
    // reuse in the next iteration.
    enif_get_list_cell(env, tail, &head, &tail);
    enif_inspect_binary(env, head, &current_bin);
    sky_env[i] = BINARY_TO_BUF(current_bin);
  }

  // Let's load the instrumenter into the `instrumenter` variable.
  sky_instrumenter_t *instrumenter;
  MAYBE_RAISE_FFI(sky_instrumenter_new(sky_env, (int) envc, &instrumenter));

  sky_instrumenter_t **resource =
    enif_alloc_resource(INSTRUMENTER_RES_TYPE, sizeof(sky_instrumenter_t *));

  memcpy((void *) resource, (void *) &instrumenter, sizeof(sky_instrumenter_t *));

  ERL_NIF_TERM term = enif_make_resource(env, resource);

  // Not sure if this is necessary yet:
  // enif_release_resource(resource);

  return term;
}

// Wraps:
//   int sky_instrumenter_start(const sky_instrumenter_t* inst);
// in:
//   instrumenter_start(instrumenter :: <resource>) :: :ok | :error
static ERL_NIF_TERM instrumenter_start(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[]) {
  sky_instrumenter_t *instrumenter;
  get_instrumenter(env, argv[0], &instrumenter);

  int res = sky_instrumenter_start(instrumenter);
  return FFI_RESULT(res);
}

// Wraps:
//   int sky_instrumenter_stop(sky_instrumenter_t* inst);
// in:
//   instrumenter_stop(instrumenter :: <resource>) :: :ok | :error
static ERL_NIF_TERM instrumenter_stop(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[]) {
  sky_instrumenter_t *instrumenter;
  get_instrumenter(env, argv[0], &instrumenter);

  int res = sky_instrumenter_stop(instrumenter);
  return FFI_RESULT(res);
}

// Wraps:
//   int sky_trace_new(uint64_t start, sky_buf_t uuid, sky_buf_t endpoint, sky_trace_t** out);
// as
//   trace_new(start :: integer, uuid :: binary, endpoint :: binary) :: <resource>
static ERL_NIF_TERM trace_new(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[]) {
  ErlNifUInt64 start;
  enif_get_uint64(env, argv[0], &start);
  ErlNifBinary uuid_bin, endpoint_bin;
  enif_inspect_binary(env, argv[1], &uuid_bin);
  enif_inspect_binary(env, argv[2], &endpoint_bin);

  sky_buf_t uuid_buf = BINARY_TO_BUF(uuid_bin);
  sky_buf_t endpoint_buf = BINARY_TO_BUF(endpoint_bin);

  sky_trace_t *trace;
  MAYBE_RAISE_FFI(sky_trace_new((uint64_t) start, uuid_buf, endpoint_buf, &trace));

  sky_trace_t **resource = enif_alloc_resource(TRACE_RES_TYPE, sizeof(sky_trace_t *));
  memcpy((void *) resource, (void *) &trace, sizeof(sky_trace_t *));

  ERL_NIF_TERM term = enif_make_resource(env, resource);

  return term;
}

// Wraps:
//   int sky_trace_start(sky_trace_t* trace, uint64_t* out);
// as
//   trace_start(trace :: <resource>) :: integer
static ERL_NIF_TERM trace_start(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[]) {
  sky_trace_t *trace;
  get_trace(env, argv[0], &trace);

  uint64_t out;
  MAYBE_RAISE_FFI(sky_trace_start(trace, &out));

  return enif_make_uint64(env, (ErlNifUInt64) out);
}

// Wraps:
//   int sky_trace_endpoint(sky_trace_t* trace, sky_buf_t* out);
// in:
//   trace_endpoint(trace :: <resource>) :: binary
static ERL_NIF_TERM trace_endpoint(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[]) {
  sky_trace_t *trace;
  get_trace(env, argv[0], &trace);

  sky_buf_t endpoint_buf;
  MAYBE_RAISE_FFI(sky_trace_endpoint(trace, &endpoint_buf));

  ErlNifBinary endpoint_bin = BUF_TO_BINARY(endpoint_buf);

  return enif_make_binary(env, &endpoint_bin);
}

// Wraps:
//   int sky_lex_sql(sky_buf_t sql, sky_buf_t* title_buf, sky_buf_t* desc_buf);
// in:
//   lex_sql(sql :: binary) :: binary
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


// Helper functions.

void get_instrumenter(ErlNifEnv *env, ERL_NIF_TERM resource_arg, sky_instrumenter_t **instrumenter) {
  sky_instrumenter_t **resource;
  enif_get_resource(env, resource_arg, INSTRUMENTER_RES_TYPE, (void *) &resource);
  *instrumenter = *resource;
}

void get_trace(ErlNifEnv *env, ERL_NIF_TERM resource_arg, sky_trace_t **trace) {
  sky_trace_t **resource;
  enif_get_resource(env, resource_arg, TRACE_RES_TYPE, (void *) &resource);
  *trace = *resource;
}


// List of functions to define in the module that loads this NIF file.
static ErlNifFunc nif_funcs[] = {
  {"load_libskylight", 1, load_libskylight},
  {"hrtime", 0, hrtime},
  {"instrumenter_new", 1, instrumenter_new},
  {"instrumenter_start", 1, instrumenter_start},
  {"instrumenter_stop", 1, instrumenter_stop},
  {"trace_new", 3, trace_new},
  {"trace_start", 1, trace_start},
  {"trace_endpoint", 1, trace_endpoint},
  {"lex_sql", 1, lex_sql}
};


// Where the magic happens.
// Defines the NIFs listed in `nif_funcs` in the module passed as the first
// argument to this macro. The last four arguments are load/unload/reload hooks
// called by Erlang.
ERL_NIF_INIT(Elixir.Skylight.NIF, nif_funcs, &load, NULL, NULL, NULL);
