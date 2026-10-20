# Bundled fonts

Flutter web downloads every bundled font before the first frame, so these
are trimmed to what LuzHire uses (Phase 10). All three are SIL OFL 1.1 with
no Reserved Font Names, so modified copies keep their names.

- **Inter**: optical-size axis pinned at its default (`opsz=14`, the only
  value the app renders), weight axis kept (100–900).
- **All three**: Latin, Latin Extended, Vietnamese, punctuation, currency
  (including ₹), arrows, maths, box shapes; hinting dropped (Flutter's
  renderer does not use it). Other scripts fall back to Noto fonts.

Total: 1,240 KB → 687 KB. To rebuild from the original files (`pip install fonttools`):

```bash
python -m fontTools.varLib.instancer Inter-Variable.ttf opsz=14 -o Inter-opsz14.ttf
U="U+0000-024F,U+02B0-02FF,U+0300-036F,U+1E00-1EFF,U+2000-206F,U+2070-209F,U+20A0-20CF,U+2100-214F,U+2150-218F,U+2190-21FF,U+2200-22FF,U+2300-23FF,U+2460-24FF,U+25A0-25FF,U+2713-2714,U+FB00-FB06,U+FEFF,U+FFFD"
python -m fontTools.subset Inter-opsz14.ttf --unicodes="$U" --layout-features='*' --no-hinting --name-IDs='*' --name-languages='*' --notdef-outline --output-file=Inter-Variable.ttf
# same subset command for PlusJakartaSans-Variable.ttf and JetBrainsMono-Variable.ttf (no instancer step)
```
