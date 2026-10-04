---
description: "Authoritative DAME rules for the Godot port. Read before touching dame_rules.gd."
connections: [architecture, ui]
---

# Rules

Source of truth: `godot/scripts/dame_rules.gd` and `CONCEPT_DECISIONS.md`. `src/lib/gameLogic.ts` is reference only. On conflict, the Godot code and the concept decisions win.

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

## State (Dictionary `rules.state`)

- `players[]`: `seat`, `name`, `is_ai`, `difficulty`, `hand[]`, `known[]` (own hand indexes the player knows), `seen_ids[]` (foreign card ids the player has peeked), `penalty_cards[]`, `score`, `total_score`, `eliminated`, `locked`, `has_called_dame`
- `seat_count` 2–4, `seed`, `deal` (deal number), `round` (circuit inside the deal)
- `deck[]`, `discard[]`, `drawn_card`
- `phase`: `play`, `dame_called`, `round_end`, `game_over`
- `turn_step`: `draw`, `play`, `jack`, `king`, `extra`
- `current_index`, `round_start_index`, `dame_caller_index`, `dame_turns_left`, `winner_index`
- `safe_phase`: first two circuits of every deal. Dame call, forced queen and extra discard are off.
- `last_action` (German), `log[]`

## Setup

`start_match(config)`: seeded shuffle, deal 4 to every seat, slots 0 and 1 known to their owner only. Rest of the pool is the deck. Config: `seed`, `seat_count`, `names`, `ai_seats`, `difficulties`.

## Turn

1. `draw`: from deck or discard top. Open queen on top outside safe phase forces taking it.
2. `play`: `swap` (drawn card into a hand slot, old card to discard) or `discard_drawn`.
3. Discarded J ⇒ `jack` step, K ⇒ `king` step, Q ⇒ discarder takes one penalty card. Else `extra` step.
4. `extra`: optional `discard_extra` of a hand card with the same rank as the discard top (refill from deck). Mismatch ⇒ one penalty card, action fails. Hand empty after a legal extra ⇒ Dame is called automatically. Then `end_turn`.

Empty deck: discard except its top is reshuffled with a seed. Deck and discard both empty ⇒ the action fails with a German reason, no phantom card.

## Power cards

| Card | Resolution |
|---|---|
| J | Peek any face-down slot, own or opponent. Own ⇒ index into `known`. Foreign ⇒ id into `seen_ids`. No swap. |
| K | Peek one own face-down slot, then blind swap it with one opponent slot. Opponent card stays unseen. Both end face-down. |
| A | No effect. Normal rank, 1 point. |
| 10 | No effect. Normal rank, 10 points. |
| Q | Open queen on discard forces the next drawer to take it (outside safe phase). Discarding a queen gives the discarder one penalty card. |

`PENALTY_CARD_COUNT = 1`. Do not inflate.

## Dame call

`can_call_dame`: phase `play`, not safe phase, no caller yet, at start of own turn.

`call_dame`: phase `dame_called`, caller locked, every other living player plays exactly one more turn.

Resolution: caller wins only with strictly fewer points than every other living player. Equal ⇒ wrong call ⇒ caller gets one penalty card for the next deal (5 cards instead of 4).

Scores: hand + penalty points into `total_score`. Exactly 50 resets to 0. Over 50 eliminates. After a deal, if at most one living player remains, or no living human remains while humans took part, phase is `game_over` and `winner_index` is the living player with the lowest `total_score`.

## Illegal moves the tests must reject

- Dame call in safe phase, after a caller exists, or mid-turn
- Acting out of turn
- Extra discard of a rank that is not discard top without paying the penalty
- Drawing from an empty discard
- AI policy receiving `DameRules` instead of a view
- Two zones containing the same card id

Seed every shuffle. Tests pass the seed in. No `randf()` inside rules.
