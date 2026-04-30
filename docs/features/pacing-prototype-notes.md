# Pacing Prototype Notes

Issue: RGR-146

## Prototype Data

- Session window: 5h.
- Weekly window: 7d.
- Expected usage is the elapsed window percentage.
- Delta is actual used percentage minus expected usage percentage.
- Samples cover under pace, near pace, moderately over pace, severely over pace, and missing usage/reset data.

## Variants Reviewed

- Inline Marker: compact and readable, but adding copy beside every row makes the card feel busy.
- Below Label Ghost: understandable after inspection, but it spends an extra line per row and weakens scan density.
- Right Badge Band: strongest compact option. The bar shows expected range, the delta badge gives exact magnitude, and reset copy can stay on the right/below side.
- Bar Only: cleanest visual option, but too subtle without teaching text; users can miss what the secondary tone means.
- Expanded Detail: best for learning/debugging, too tall for the normal current-account card.

## Recommended Direction

Use the current local and current remote account cards only for the first production implementation. Put pacing on the existing session and weekly rows with an expected marker or narrow expected band plus a small numeric delta badge near the reset side.

Prefer neutral/accent visuals first: existing accent fill, neutral expected marker/band, and restrained orange only for clearly over-pace states. Avoid red/green in the first production pass because the prototype makes red read like an error before the user is actually blocked.

Recommended wording: keep production copy minimal. Use `On pace`, `Over pace`, and `Room left` only when text is necessary; otherwise use a compact numeric badge such as `+20` or `-30`.

## Rejected For V1

- All saved account rows: too dense for the current menu and likely to make account scanning worse.
- Friendly copy such as `Fast` or `Plenty left`: short, but less precise and slightly judgmental.
- Bar-only encoding: elegant but not self-explanatory enough for a first shipped version.
- Expanded-only detail: useful for debug review, not useful for at-a-glance account choice.
