{
  lib,
  buildPythonPackage,
  fetchFromGitHub,
  pythonOlder,
  stdenvNoCC,
  replaceVars,

  # build
  setuptools,

  # dependencies
  aiohttp,
  aiorun,
  async-timeout,
  atomicwrites,
  coloredlogs,
  orjson,
  home-assistant-chip-clusters,

  # optionals
  cryptography,
  home-assistant-chip-core,
  zeroconf,

  # tests
  aioresponses,
  python,
  pytest,
  pytest-aiohttp,
  pytest-cov-stub,
  pytestCheckHook,
}:

let
  paaCerts = stdenvNoCC.mkDerivation rec {
    pname = "matter-server-paa-certificates";
    version = "1.4.0.0";

    src = fetchFromGitHub {
      owner = "project-chip";
      repo = "connectedhomeip";
      rev = "refs/tags/v${version}";
      hash = "sha256-uJyStkwynPCm1B2ZdnDC6IAGlh+BKGfJW7tU4tULHFo=";
    };

    installPhase = ''
      runHook preInstall

      mkdir -p $out
      cp $src/credentials/development/paa-root-certs/* $out/

      runHook postInstall
    '';
  };
in

buildPythonPackage rec {
  pname = "python-matter-server";
  version = "7.0.1";
  pyproject = true;

  disabled = pythonOlder "3.10";

  src = fetchFromGitHub {
    owner = "home-assistant-libs";
    repo = "python-matter-server";
    rev = "refs/tags/${version}";
    hash = "sha256-kwN7mLSKrxsAydp7PnN7kTvvi5zQSpXVwMh2slL6aIA=";
  };

  patches = [
    (replaceVars ./link-paa-root-certs.patch {
      paacerts = paaCerts;
    })
  ];

  postPatch = ''
    substituteInPlace pyproject.toml \
      --replace 'version = "0.0.0"' 'version = "${version}"'
  '';

  build-system = [
    setuptools
  ];

  pythonRelaxDeps = [ "home-assistant-chip-clusters" ];

  dependencies = [
    aiohttp
    aiorun
    async-timeout
    atomicwrites
    coloredlogs
    orjson
    home-assistant-chip-clusters
  ];

  optional-dependencies = {
    server = [
      cryptography
      home-assistant-chip-core
      zeroconf
    ];
  };

  nativeCheckInputs = [
    aioresponses
    pytest-aiohttp
    pytest-cov-stub
    pytestCheckHook
  ] ++ lib.flatten (lib.attrValues optional-dependencies);

  preCheck =
    let
      pythonEnv = python.withPackages (_: dependencies ++ nativeCheckInputs ++ [ pytest ]);
    in
    ''
      export PYTHONPATH=${pythonEnv}/${python.sitePackages}
    '';

  disabledTestPaths = [
    # requires internet access
    "tests/server/ota/test_dcl.py"
  ];

  meta = with lib; {
    changelog = "https://github.com/home-assistant-libs/python-matter-server/releases/tag/${version}";
    description = "Python server to interact with Matter";
    mainProgram = "matter-server";
    homepage = "https://github.com/home-assistant-libs/python-matter-server";
    license = licenses.asl20;
    teams = [ teams.home-assistant ];
  };
}
