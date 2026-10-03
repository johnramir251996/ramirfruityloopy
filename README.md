# Pinoy Creator Map

A map of Filipino creators. Each city or municipality has a fixed number of slots, plus one premium **#1 spot**. Creators claim a slot, you review and collect payment, and their tile goes live on the map and in the directory.

This is the clickable prototype: map, city slot boards, creator profiles, directory search, and the claim form, wired to a live Supabase database.

## What's here

| Path | What it is |
|---|---|
| `index.html` | The whole site: one static page, no build step |
| `supabase/migrations/001_schema.sql` | Tables, security rules, claim and admin functions |
| `supabase/migrations/002_seed_launch_cities.sql` | 12 launch cities, their slots, and 16 demo creators |

Database: Supabase project **pinoy-creator-map** (Singapore region).

## How a claim works

1. A creator taps an open slot and fills in the form (name, niche, followers, barangay, channel links, email, tile color).
2. The `request_claim` function checks the input and holds the slot for **24 hours**. Two people can't hold the same slot.
3. You review the claim and send a payment link (GCash, Maya or card).
4. After payment, you approve it and the tile goes live.

### Reviewing claims (Supabase dashboard → SQL editor)

```sql
-- See pending claims
select * from admin_pending_claims;

-- Approve (tile goes live)
select approve_creator('CREATOR-ID-HERE');

-- Reject (slot opens again)
select reject_creator('CREATOR-ID-HERE');
```

## Security

- Row-level security is on for every table.
- The public can read cities, slots and **approved** creators only. Contact emails are never readable from the website.
- The public can't insert or update anything directly. The only write is `request_claim`, which validates every field, only accepts real TikTok / YouTube / Facebook links, blocks taken slots, and limits spam (3 pending claims per email, 200 per hour overall).
- `approve_creator` and `reject_creator` can only be run by you from the dashboard.
- The key in `index.html` is a **publishable** key. It's meant to be public; the security rules above are what protect the data.

Supabase's linter shows a warning that `request_claim` can be called by anonymous users. That is intentional: it is the claim form's single entry point.

## Run it

Open `index.html` in a browser, or host it anywhere static.

**GitHub Pages:** repo Settings → Pages → Source: *Deploy from a branch* → Branch: `pinoy-creator-map`, folder `/ (root)`. The site will be at `https://johnramir251996.github.io/ramirfruityloopy/`.

If the database can't be reached, the page falls back to a built-in snapshot and shows **Preview data** in the header.

## Pricing in the seed data

| Tier | Slots | Slot price | #1 spot |
|---|---|---|---|
| Major city (QC, Manila, Cebu, Davao) | 60 | ₱2,000 | ₱10,000 |
| Makati | 40 | ₱2,500 | ₱12,000 |
| Mid-size city | 25 | ₱1,000 | ₱5,000 |
| Small city / municipality | 10 | ₱400 | ₱2,000 |

Change prices any time in the `places` table.

## Next steps

- **Payments:** PayMongo or Xendit checkout, with a webhook that approves the claim automatically after payment.
- **Logo uploads:** PNG/JPG only, size-limited, stored privately until approved. Tiles currently show initials in the creator's color.
- **Real boundaries:** replace the simplified pixel map with official PSA (PSGC) city and municipality shapes, and fill in `psgc_code`.
- **Channel verification:** ask creators to put a short code in their TikTok/YouTube bio before approval.
- **Admin page:** a password-protected review screen instead of SQL.
- Remove the demo creators before launch: `delete from creators where is_demo;` (their slots reopen automatically after `update slots set status='available' where creator_id is null and status='live';`).
