{ lib
, buildPythonPackage
, fetchFromGitHub
, pytestCheckHook
, pythonAtLeast
, pythonOlder
, setuptools
, six
}:

buildPythonPackage rec {
  pname = "paste";
  version = "3.8.0";
  format = "setuptools";

  disabled = pythonOlder "3.7";

  src = fetchFromGitHub {
    owner = "cdent";
    repo = "paste";
    rev = "refs/tags/${version}";
    hash = "sha256-T9VG91Y8hap1nt3FkuCGsv8nglWNlRajvsvljXexH3Y=";
  };

  postPatch = ''
    patchShebangs tests/cgiapp_data/
  '';

  propagatedBuildInputs = [
    setuptools
    six
  ];

  nativeCheckInputs = [
    pytestCheckHook
  ];

  preCheck = ''
    # needs to be modified after Sat, 1 Jan 2005 12:00:00 GMT
    touch tests/urlparser_data/secured.txt
  '';

  pythonNamespaces = [
    "paste"
  ];

  meta = with lib; {
    description = "Tools for using a Web Server Gateway Interface stack";
    homepage = "https://pythonpaste.readthedocs.io/";
    changelog = "https://github.com/cdent/paste/blob/${version}/docs/news.txt";
    license = licenses.mit;
    maintainers = with maintainers; [ ];
  };
}
