Subresource Integrity
=====================

Editor's draft: https://w3c.github.io/webappsec-subresource-integrity/

The spec text is written in [Bikeshed]. After editing `index.bs`, you can
generate a new HTML draft by typing `make` on the command line. Note that this
requires an active internet connection to download up-to-date config files.

You can publish a new draft by typing `make publish` (which simply pushes
the local `master` branch to GitHub's `gh-pages` branch).

Please do not modify `spec_v1.markdown` or its compiled file,
`index.kramdown.html`. These are the spec files from version 1 of the spec,
which was originally written in Kramdown, but work is now done exclusively in
`index.bs`.

Pull requests happily reviewed.

[bikeshed]: https://github.com/tabatkins/bikeshed
 
