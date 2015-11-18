#include <stdio.h>
#include <string.h>
#include "erl_nif.h"
#include "skylight_dlopen.h"

// Bunch of macros.

// Raises an Erlang exception with `msg` as the reason (as an Erlang char list).
#define ERL_RAISE(msg) return enif_raise_exception(env, enif_make_string(env, (msg), ERL_NIF_LATIN1))

// Returns `ok` if `res` is 0 (success), `error` otherwise.
#define FFI_RESULT(res) ((res) == 0) ? atom_ok : atom_error

// Raises if the native function returns non-0.
#define MAYBE_RAISE_FFI(ffi_call)                   \
  do {                                              \
    if ((ffi_call) != 0) {                          \
      ERL_RAISE("call to native function failed");  \
    }                                               \
  } while (0)

#define RAISE_IF_LIBSKYLIGHT_NOT_LOADED()       \
  do {                                          \
    if (sky_hrtime == 0) {                      \
      ERL_RAISE("libskylight not loaded");      \
    }                                           \
  } while (0)

#define CHECK_TYPE(arg, type)                   \
  do {                                          \
    if (!enif_is_##type(env, arg))  {           \
      return enif_make_badarg(env);             \
    }                                           \
  } while (0)


// Helper function headers.
sky_buf_t bin2buf(ErlNifBinary bin);
ErlNifBinary buf2bin(sky_buf_t buf);
void get_instrumenter(ErlNifEnv *, ERL_NIF_TERM, sky_instrumenter_t **);
void get_trace(ErlNifEnv *, ERL_NIF_TERM, sky_trace_t **);


// Global atoms to be used throughout the functions.
ERL_NIF_TERM atom_ok;
ERL_NIF_TERM atom_loaded;
ERL_NIF_TERM atom_already_loaded;
ERL_NIF_TERM atom_error;
ERL_NIF_TERM atom_true;
ERL_NIF_TERM atom_false;

// Resource type for Skylight instrumenters. It's initialized in the `load`
// function.
ErlNifResourceType *INSTRUMENTER_RES_TYPE;

// Resource type for Skylight traces. Initialized in the `load` function.
ErlNifResourceType *TRACE_RES_TYPE;

// Destructor for `INSTRUMENTER_RES_TYPE` resources.
void instrumenter_res_destructor(ErlNifEnv *env, void *obj) {
  sky_instrumenter_t **inst_res = obj;
  sky_instrumenter_free(*inst_res);
}

// Destructor for `TRACE_RES_TYPE` resources.
void trace_res_destructor(ErlNifEnv *env, void *obj) {
  // Ok, let's do something weird here. There's a function in the sky_* API that
  // frees a trace after it's called (in Rust, it takes the trace as a
  // Box<Trace> with no &): sky_instrumenter_submit_trace().
  // If we called sky_trace_free() blindly here, we would run into "pointed
  // being freed was not allocated" errors (because the trace has already been
  // freed). To overcome this, we're going to null out the trace just after
  // calling sky_instrumenter_submit_trace(), and we'll free the trace here only
  // if it's not null. We can do this here because we're passing Erlang
  // resources around, which are pointers to traces and instrumenters: this way,
  // the resource pointer always stays valid but at some point it will point to
  // NULL.
  sky_trace_t **trace_res = obj;

  if (*trace_res != NULL) {
    sky_trace_free(*trace_res);
  }
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
  atom_true = enif_make_atom(env, "true");
  atom_false = enif_make_atom(env, "false");

  // ERL_NIF_RT_CREATE creates a new resource type, while ERL_NIF_RT_TAKEOVER
  // opens an existing resource type and takes ownership of all the instances of
  // that resource type.
  int res_flags = ERL_NIF_RT_CREATE | ERL_NIF_RT_TAKEOVER;

  INSTRUMENTER_RES_TYPE =
    enif_open_resource_type(env, NULL, "instrumenter", instrumenter_res_destructor, res_flags, NULL);
  TRACE_RES_TYPE =
    enif_open_resource_type(env, NULL, "trace", trace_res_destructor, res_flags, NULL);

  return 0;
}

// Wraps:
//   int sky_load_libskylight(const char* filename);
// in:
//   load_libskylight(filename :: binary) :: {:ok, :loaded | :already_loaded} | :error
static ERL_NIF_TERM load_libskylight(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[]) {
  // Return early if the lib was already loaded (we're checking for the
  // existence of the sky_hrtime function here).
  if (sky_hrtime != 0) {
    return enif_make_tuple2(env, atom_ok, atom_already_loaded);
  }

  CHECK_TYPE(argv[0], binary);

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
  RAISE_IF_LIBSKYLIGHT_NOT_LOADED();

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
  RAISE_IF_LIBSKYLIGHT_NOT_LOADED();

  ERL_NIF_TERM erl_env = argv[0];
  sky_buf_t sky_env[256];

  CHECK_TYPE(argv[0], list);

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

  for (unsigned int i = 0; i < envc; i++) {
    ErlNifBinary current_bin;

    // Replace `head` with the current element and `tail` with the new tail to
    // reuse in the next iteration.
    enif_get_list_cell(env, tail, &head, &tail);
    enif_inspect_binary(env, head, &current_bin);
    sky_env[i] = bin2buf(current_bin);
  }

  // `resource` is now a pointer to a `sky_instrumenter_t *` (for which we
  // allocated the memory).
  sky_instrumenter_t **inst_res =
    enif_alloc_resource(INSTRUMENTER_RES_TYPE, sizeof(sky_instrumenter_t *));
  // We can already create the Erlang term for the resource and release the
  // resource, giving its ownership to Erlang.
  ERL_NIF_TERM term = enif_make_resource(env, inst_res);
  enif_release_resource(inst_res);

  // We're now loading the new instrumenter (which is a `sky_instrumenter_t *`)
  // into the memory pointed by `inst_res`.
  MAYBE_RAISE_FFI(sky_instrumenter_new(sky_env, (int) envc, inst_res));

  return term;
}

// Wraps:
//   int sky_instrumenter_start(const sky_instrumenter_t* inst);
// in:
//   instrumenter_start(instrumenter :: <resource>) :: :ok | :error
static ERL_NIF_TERM instrumenter_start(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[]) {
  RAISE_IF_LIBSKYLIGHT_NOT_LOADED();

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
  RAISE_IF_LIBSKYLIGHT_NOT_LOADED();

  sky_instrumenter_t *instrumenter;
  get_instrumenter(env, argv[0], &instrumenter);

  int res = sky_instrumenter_stop(instrumenter);
  return FFI_RESULT(res);
}

// Wraps:
//   int sky_instrumenter_submit_trace(const sky_instrumenter_t* inst, sky_trace_t* trace);
// in:
//   instrumenter_submit_trace(inst :: <resource>, trace :: <resource>) :: :ok | :error
static ERL_NIF_TERM instrumenter_submit_trace(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[]) {
  RAISE_IF_LIBSKYLIGHT_NOT_LOADED();

  sky_instrumenter_t *instrumenter;
  get_instrumenter(env, argv[0], &instrumenter);

  sky_trace_t **trace_res;
  enif_get_resource(env, argv[1], TRACE_RES_TYPE, (void **) &trace_res);

  int res = sky_instrumenter_submit_trace((const sky_instrumenter_t *) instrumenter, *trace_res);

  // sky_instrumenter_submit_trace() frees the trace, but to be sure let's NULL
  // it out manually.
  if (res == 0) {
    *trace_res = NULL;
  }

  return FFI_RESULT(res);
}

// Wraps:
//   int sky_instrumenter_track_desc(sky_instrumenter_t* inst, sky_buf_t endpoint, sky_buf_t desc, int* out);
// in:
//   instrumenter_track_desc(instrumenter :: <resource>, endpoint :: binary, desc :: binary) :: boolean
static ERL_NIF_TERM instrumenter_track_desc(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[]) {
  RAISE_IF_LIBSKYLIGHT_NOT_LOADED();

  CHECK_TYPE(argv[1], binary);
  CHECK_TYPE(argv[2], binary);

  sky_instrumenter_t *instrumenter;
  get_instrumenter(env, argv[0], &instrumenter);

  ErlNifBinary endpoint_bin, desc_bin;
  enif_inspect_binary(env, argv[1], &endpoint_bin);
  enif_inspect_binary(env, argv[2], &desc_bin);

  sky_buf_t endpoint_buf = bin2buf(endpoint_bin);
  sky_buf_t desc_buf = bin2buf(desc_bin);

  int tracked = 0;
  int res = sky_instrumenter_track_desc(instrumenter, endpoint_buf, desc_buf, &tracked);

  if (res != 0) {
    ERL_RAISE("call to native function failed");
  }

  return tracked ? atom_true : atom_false;
}

// Wraps:
//   int sky_trace_new(uint64_t start, sky_buf_t uuid, sky_buf_t endpoint, sky_trace_t** out);
// as
//   trace_new(start :: integer, uuid :: binary, endpoint :: binary) :: <resource>
static ERL_NIF_TERM trace_new(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[]) {
  RAISE_IF_LIBSKYLIGHT_NOT_LOADED();
  CHECK_TYPE(argv[0], number);
  CHECK_TYPE(argv[1], binary);
  CHECK_TYPE(argv[2], binary);

  ErlNifUInt64 start;
  enif_get_uint64(env, argv[0], &start);
  ErlNifBinary uuid_bin, endpoint_bin;
  enif_inspect_binary(env, argv[1], &uuid_bin);
  enif_inspect_binary(env, argv[2], &endpoint_bin);

  // We allocate the space for a trace resource, which is just a pointer to a
  // `sky_trace_t`.
  sky_trace_t **trace_res = enif_alloc_resource(TRACE_RES_TYPE, sizeof(sky_trace_t *));
  // We then immediately create the Erlang resource...
  ERL_NIF_TERM term = enif_make_resource(env, trace_res);
  // ...and immediately release the resource, transferring its ownership to
  // Erlang. It will be freed when garbage-collected by Erlang.
  enif_release_resource(trace_res);

  // Now, we can fill the memory pointed by the resource.
  MAYBE_RAISE_FFI(sky_trace_new((uint64_t) start,
                                bin2buf(uuid_bin),
                                bin2buf(endpoint_bin),
                                trace_res));

  return term;
}

// Wraps:
//   int sky_trace_start(sky_trace_t* trace, uint64_t* out);
// as
//   trace_start(trace :: <resource>) :: integer
static ERL_NIF_TERM trace_start(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[]) {
  RAISE_IF_LIBSKYLIGHT_NOT_LOADED();

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
  RAISE_IF_LIBSKYLIGHT_NOT_LOADED();

  sky_trace_t *trace;
  get_trace(env, argv[0], &trace);

  sky_buf_t endpoint_buf;
  MAYBE_RAISE_FFI(sky_trace_endpoint(trace, &endpoint_buf));

  ErlNifBinary endpoint_bin = buf2bin(endpoint_buf);

  return enif_make_binary(env, &endpoint_bin);
}

// Wraps:
//   int sky_trace_set_endpoint(const sky_trace_t* trace, sky_buf_t endpoint);
// in:
//   trace_set_endpoint(trace :: <resource>, endpoint :: binary) :: :ok | :error
static ERL_NIF_TERM trace_set_endpoint(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[]) {
  RAISE_IF_LIBSKYLIGHT_NOT_LOADED();

  CHECK_TYPE(argv[1], binary);

  sky_trace_t *trace;
  get_trace(env, argv[0], &trace);

  ErlNifBinary endpoint_bin;
  enif_inspect_binary(env, argv[1], &endpoint_bin);

  sky_buf_t endpoint_buf = bin2buf(endpoint_bin);

  int res = sky_trace_set_endpoint(trace, endpoint_buf);
  return FFI_RESULT(res);
}

// Wraps:
//   int sky_trace_uuid(sky_trace_t* trace, sky_buf_t* out);
// in:
//   trace_uuid(trace :: <resource>) :: binary
static ERL_NIF_TERM trace_uuid(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[]) {
  RAISE_IF_LIBSKYLIGHT_NOT_LOADED();

  sky_trace_t *trace;
  get_trace(env, argv[0], &trace);

  sky_buf_t uuid_buf;
  MAYBE_RAISE_FFI(sky_trace_uuid(trace, &uuid_buf));

  ErlNifBinary uuid_bin = buf2bin(uuid_buf);

  return enif_make_binary(env, &uuid_bin);
}

// Wraps:
//   int sky_trace_set_uuid(const sky_trace_t* trace, sky_buf_t uuid);
// in:
//   trace_set_uuid(trace :: <resource>, uuid :: binary) :: :ok | :error
static ERL_NIF_TERM trace_set_uuid(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[]) {
  RAISE_IF_LIBSKYLIGHT_NOT_LOADED();

  CHECK_TYPE(argv[1], binary);

  sky_trace_t *trace;
  get_trace(env, argv[0], &trace);

  ErlNifBinary uuid_bin;
  enif_inspect_binary(env, argv[1], &uuid_bin);

  sky_buf_t uuid_buf = bin2buf(uuid_bin);

  int res = sky_trace_set_uuid(trace, uuid_buf);
  return FFI_RESULT(res);
}

// Wraps:
//   int sky_trace_instrument(const sky_trace_t* trace, uint64_t time, sky_buf_t category, uint32_t* out);
// in:
//   trace_instrument(trace :: <resource>, time :: non_neg_integer, category :: binary) :: non_neg_integer
static ERL_NIF_TERM trace_instrument(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[]) {
  RAISE_IF_LIBSKYLIGHT_NOT_LOADED();

  CHECK_TYPE(argv[1], number);
  CHECK_TYPE(argv[2], binary);

  sky_trace_t *trace;
  get_trace(env, argv[0], &trace);

  uint64_t time;
  enif_get_uint64(env, argv[1], (ErlNifUInt64 *) &time);

  ErlNifBinary category_bin;
  enif_inspect_binary(env, argv[2], &category_bin);

  sky_buf_t category_buf = bin2buf(category_bin);

  uint32_t out;
  MAYBE_RAISE_FFI(sky_trace_instrument(trace, time, category_buf, &out));

  return enif_make_uint(env, (unsigned int) out);
}

// Wraps:
//   int sky_trace_span_set_title(const sky_trace_t* trace, uint32_t handle, sky_buf_t title);
// in:
//   trace_span_set_title(trace :: <resource>, handle :: non_neg_integer, title :: binary) :: :ok | :error
static ERL_NIF_TERM trace_span_set_title(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[]) {
  RAISE_IF_LIBSKYLIGHT_NOT_LOADED();

  CHECK_TYPE(argv[1], number);
  CHECK_TYPE(argv[2], binary);

  sky_trace_t *trace;
  get_trace(env, argv[0], &trace);

  uint32_t handle;
  enif_get_uint(env, argv[1], (unsigned int *) &handle);

  ErlNifBinary title_bin;
  enif_inspect_binary(env, argv[2], &title_bin);

  sky_buf_t title_buf = bin2buf(title_bin);

  int res = sky_trace_span_set_title(trace, handle, title_buf);
  return FFI_RESULT(res);
}

// Wraps:
//   int sky_trace_span_set_desc(const sky_trace_t* trace, uint32_t handle, sky_buf_t desc);
// in:
//   trace_span_set_desc(trace :: <resource>, handle :: non_neg_integer, desc :: binary) :: :ok | :error
static ERL_NIF_TERM trace_span_set_desc(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[]) {
  RAISE_IF_LIBSKYLIGHT_NOT_LOADED();

  CHECK_TYPE(argv[1], number);
  CHECK_TYPE(argv[2], binary);

  sky_trace_t *trace;
  get_trace(env, argv[0], &trace);

  uint32_t handle;
  enif_get_uint(env, argv[1], (unsigned int *) &handle);

  ErlNifBinary desc_bin;
  enif_inspect_binary(env, argv[2], &desc_bin);

  sky_buf_t desc_buf = bin2buf(desc_bin);

  int res = sky_trace_span_set_desc(trace, handle, desc_buf);
  return FFI_RESULT(res);
}

// Wraps:
//   int sky_trace_span_done(const sky_trace_t* trace, uint32_t handle, uint64_t time);
// in:
//   trace_span_done(trace :: <resource>, handle :: non_neg_integer, time :: non_neg_integer) :: :ok | :error
static ERL_NIF_TERM trace_span_done(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[]) {
  RAISE_IF_LIBSKYLIGHT_NOT_LOADED();

  CHECK_TYPE(argv[1], number);
  CHECK_TYPE(argv[2], number);

  sky_trace_t *trace;
  get_trace(env, argv[0], &trace);

  uint32_t handle;
  enif_get_uint(env, argv[1], (unsigned int *) &handle);

  uint32_t time;
  enif_get_uint(env, argv[2], (unsigned int *) &time);

  int res = sky_trace_span_done(trace, handle, time);
  return FFI_RESULT(res);
}

// Wraps:
//   int sky_lex_sql(sky_buf_t sql, sky_buf_t* title_buf, sky_buf_t* desc_buf);
// in:
//   lex_sql(sql :: binary) :: binary
static ERL_NIF_TERM lex_sql(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[]) {
  RAISE_IF_LIBSKYLIGHT_NOT_LOADED();

  CHECK_TYPE(argv[0], binary);

  ErlNifBinary sql_bin;
  enif_inspect_binary(env, argv[0], &sql_bin);

  sky_buf_t sql;
  sky_buf_t title;
  sky_buf_t statement;
  uint8_t title_store[128];

  sql = bin2buf(sql_bin);

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

sky_buf_t bin2buf(ErlNifBinary bin) {
  return (sky_buf_t) {
    .data = bin.data,
    .len = bin.size,
  };
}

ErlNifBinary buf2bin(sky_buf_t buf) {
  return (ErlNifBinary) {
    .data = buf.data,
    .size = buf.len,
  };
}

void get_instrumenter(ErlNifEnv *env, ERL_NIF_TERM resource_arg, sky_instrumenter_t **instrumenter) {
  sky_instrumenter_t **resource;
  enif_get_resource(env, resource_arg, INSTRUMENTER_RES_TYPE, (void *) &resource);
  *instrumenter = *resource;
}

void get_trace(ErlNifEnv *env, ERL_NIF_TERM resource_arg, sky_trace_t **trace) {
  sky_trace_t **trace_res;
  enif_get_resource(env, resource_arg, TRACE_RES_TYPE, (void **) &trace_res);
  *trace = *trace_res;
}


// List of functions to define in the module that loads this NIF file.
static ErlNifFunc nif_funcs[] = {
  {"load_libskylight", 1, load_libskylight},
  {"hrtime", 0, hrtime},
  {"instrumenter_new", 1, instrumenter_new},
  {"instrumenter_start", 1, instrumenter_start},
  {"instrumenter_stop", 1, instrumenter_stop},
  {"instrumenter_submit_trace", 2, instrumenter_submit_trace},
  {"instrumenter_track_desc", 3, instrumenter_track_desc},
  {"trace_new", 3, trace_new},
  {"trace_start", 1, trace_start},
  {"trace_endpoint", 1, trace_endpoint},
  {"trace_set_endpoint", 2, trace_set_endpoint},
  {"trace_uuid", 1, trace_uuid},
  {"trace_set_uuid", 2, trace_set_uuid},
  {"trace_instrument", 3, trace_instrument},
  {"trace_span_set_title", 3, trace_span_set_title},
  {"trace_span_set_desc", 3, trace_span_set_desc},
  {"trace_span_done", 3, trace_span_done},
  {"lex_sql", 1, lex_sql}
};


// Where the magic happens.
// Defines the NIFs listed in `nif_funcs` in the module passed as the first
// argument to this macro. The last four arguments are load/unload hooks
// called by Erlang; they're in this order:
// - load
// - upgrade
// - unload
// - reload (deprecated)
ERL_NIF_INIT(Elixir.Skylight.NIF, nif_funcs, &load, NULL, NULL, NULL)
