---
description: "Authoritative DAME rules for the Godot port. Read before writing dame_rules.gd."
connections: [architecture, ui]
---

# Rules

Oracle: `src/lib/gameLogic.ts` and `src/types/game.ts` in the React tree. README is a summary and loses Ace, Ten, and penalty-card details. On conflict, the TypeScript wins.

## Deck and points

52 cards. Suits hearts, diamonds, clubs, spades. Ranks A–10, J, Q, K.

| Rank | Points |
|---|---|
| A | 1 |
| 2–10 | face value |
| J | 10 |
| Q | 0 |
| K | 10 |

Q having 0 points does not make it the Dame call. See [[architecture]] for the name split.

## State

Fields the rules object must carry:

- `players[]` with `hand[4+]`, `total_score`, `is_eliminated`, `penalty_cards[]`, `is_ai`, `difficulty`
- `deck[]`, `discard_pile[]`
- `phase`, `round`, `turn_in_round`
- `current_player_index`, `round_start_player_index`
- `dame_caller_id`, `dame_call_turns_remaining`, `cards_logged`
- `safe_phase` (first two rounds, Dame call forbidden)
- `last_action` (German)
- `skip_next_player`
- per-player `memory`: map of `card_id` or `player_id+slot` to rank/suit known by that viewer

`GameConfig.power_effects` gates J/K/A/10/Q resolution. Default on, matching the playable web build.

## Setup

`initialize`: shuffle, deal 4 to each living player, first two slots known to that player only, rest unknown. Deck remainder is the draw pile. Phase `FIRST_TURN` then `REGULAR_PLAY`. 2–6 players.

## Turn

Draw from deck or from discard top. Then keep (swap into a hand slot, old card to discard) or discard the drawn card. Empty deck: reshuffle discard except its top, seeded Fisher-Yates. True empty: no silent success.

Extra discard: outside `safe_phase`, a hand card whose rank equals discard top may be discarded. Mismatch draws a penalty card instead. If the hand is empty after a legal extra discard, Dame is called automatically.

## Power cards

Only if `power_effects`.

| Card | Resolution |
|---|---|
| J | Peek any face-down slot, own or opponent. Store in viewer memory. Card stays face-down for everyone else. |
| K | Swap one own slot with one opponent slot. Both end face-down. Update both memories. |
| A | Reveal top three of deck. Optional swap of one with a hand slot. |
| 10 | Set `skip_next_player`. |
| Q | Drawer of an open queen, or discarder, takes penalty cards. |

Penalty count constant from oracle: `PENALTY_CARD_COUNT = 1` unless a call site draws more. Do not inflate.

## Dame call

`can_call_dame`: phase is regular play, not safe phase, no caller yet.

`call_dame` sets phase `DAME_CALLED`, records caller, counts remaining turns so every other living player plays once.

`end_round`: sum hand values. Caller wins the call if caller total ≤ lowest other total. Wrong call: caller receives penalty cards for the next deal (`start_next_round` appends them, so that hand starts at 5 if one penalty card). Right call: no penalty.

Score add: hand total into `total_score`. Exactly 50 resets that player to 0. Over 50 eliminates. Last living player wins. If the table ends without elimination, lowest `total_score` wins.

## Illegal moves the tests must reject

- Dame call in `safe_phase` or after a caller exists
- Peek or swap that reads a slot the actor does not own, except J/K targets declared by the action
- Extra discard of a rank that is not discard top, without paying the penalty path
- Drawing from an empty discard
- AI policy receiving another player's hand array
- Two zones containing the same card id

Seed every shuffle. Tests pass the seed in. No `randf()` inside rules.
