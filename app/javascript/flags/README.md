# Country flags

Twemoji flag SVGs, one per country in `Country::ALL`, named after the regional
indicator codepoints of the country's alpha-2 code (`US` -> `1f1fa-1f1f8.svg`).

Vendored from [jdecked/twemoji](https://github.com/jdecked/twemoji) v17.0.3,
whose npm package ships without the assets. Refresh them with:

```sh
bin/rails flags:fetch
```

Graphics are © Twitter, Inc and other contributors, licensed
[CC-BY 4.0](https://creativecommons.org/licenses/by/4.0/). Bump the tag in
`lib/tasks/flags.rake` to move to a newer Twemoji release.
