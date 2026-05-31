# Claude Model Pricing

Static price table for `compute-cost.sh`. Rates are per million tokens in USD.

## How to use this file

- **Add a new model**: append a row with the current rates and today's date as `effective_from`.
- **Rate change on an existing model**: append a NEW row (do not edit the old one). The script picks
  the row with the latest `effective_from` ≤ the turn's timestamp, so historical costs remain correct.
- **Script selection rule**: for each `model_id`, the row whose `effective_from` is the greatest date
  that is ≤ the session timestamp is used. With a single row per model this degenerates to "use the
  one row".

## Price table

| model_id | display_name | effective_from | base_input | cache_write_5m | cache_write_1h | cache_read | output |
|---|---|---|---|---|---|---|---|
| claude-opus-4-7 | Opus 4.7 | 2026-05-31 | 15.00 | 18.75 | 30.00 | 1.50 | 75.00 |
| claude-sonnet-4-6 | Sonnet 4.6 | 2026-05-31 | 3.00 | 3.75 | 6.00 | 0.30 | 15.00 |
| claude-haiku-4-5-20251001 | Haiku 4.5 | 2026-05-31 | 1.00 | 1.25 | 2.00 | 0.10 | 5.00 |
