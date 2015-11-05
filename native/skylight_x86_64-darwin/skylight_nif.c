#include "erl_nif.h"
#include "skylight_dlopen.h"

#include <stdio.h>

ERL_NIF_TERM atom_ok;
ERL_NIF_TERM atom_already_loaded;
ERL_NIF_TERM atom_error;
ERL_NIF_TERM atom_loading_failed;

int load(ErlNifEnv *env, void **priv_data, ERL_NIF_TERM load_info) {
  atom_ok = enif_make_atom(env, "ok");
  atom_already_loaded = enif_make_atom(env, "already_loaded");
  atom_error = enif_make_atom(env, "error");
  atom_loading_failed = enif_make_atom(env, "loading_failed");
  return 0;
}

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

static ErlNifFunc nif_funcs[] = {
  {"load_libskylight", 1, load_libskylight}
};

ERL_NIF_INIT(Elixir.Skylight.NIF, nif_funcs, &load, NULL, NULL, NULL);
