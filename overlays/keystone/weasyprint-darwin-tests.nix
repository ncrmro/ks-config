# weasyprint's pixel-comparison test suite fails two tests on aarch64-darwin
# (test_acid2, test_unicode_range) because macOS font rendering produces
# slightly different pixels than the reference images. These are deterministic
# failures unrelated to our usage, so append them to the package's existing
# disabledTests list to let weasyprint (pulled in transitively by keystone)
# build on macOS.
#
# TODO(upstream-keystone): move into keystone's overlay set (keystone owns the
# weasyprint dependency via its terminal/notes tooling). Holding here per the
# overlays/keystone convention in modules/keystone/AGENTS.md.
final: prev: {
  pythonPackagesExtensions = (prev.pythonPackagesExtensions or [ ]) ++ [
    (pyfinal: pyprev: {
      weasyprint = pyprev.weasyprint.overridePythonAttrs (old: {
        disabledTests = (old.disabledTests or [ ]) ++ [
          "test_acid2"
          "test_unicode_range"
        ];
      });
    })
  ];
}
