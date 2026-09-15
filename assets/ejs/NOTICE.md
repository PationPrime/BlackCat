# YouTube JS challenge solver

`yt.solver.lib.min.js` and `yt.solver.core.min.js` come unchanged from
[yt-dlp/ejs](https://github.com/yt-dlp/ejs) v0.8.0. They extract the `n`/`sig` functions from YouTube's
player JavaScript and run them; the app executes them in a hidden WebView2 (no yt-dlp, no Node).

Licenses: the scripts themselves are Unlicense (see `LICENSE`); the lib bundles
[meriyah](https://github.com/meriyah/meriyah) (ISC) and [astring](https://github.com/davidbonnet/astring) (MIT),
whose license headers are kept at the top of `yt.solver.lib.min.js`.
