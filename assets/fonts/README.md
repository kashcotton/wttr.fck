# Fonts

`GoogleSansFlex.ttf` is Google Sans Flex (SIL Open Font License 1.1, see
`OFL.txt`), from https://github.com/google/fonts/tree/main/ofl/googlesansflex.

To keep the app fast to load (especially on the web) it's an *instance* of
the original variable font: the width, slant and optical-size axes are pinned
to their defaults, which the app never changes. The weight (`wght`) and
roundness (`ROND`) axes are kept. This cuts the file from 3.9 MB to ~320 KB.

Regenerate it with:

```sh
curl -L -o GoogleSansFlex-full.ttf "https://raw.githubusercontent.com/google/fonts/main/ofl/googlesansflex/GoogleSansFlex%5BROND%2Copsz%2Cslnt%2Cwdth%2Cwght%5D.ttf"
python3 -m fontTools.varLib.instancer GoogleSansFlex-full.ttf opsz=18 wdth=100 slnt=0 -o GoogleSansFlex.ttf
```
