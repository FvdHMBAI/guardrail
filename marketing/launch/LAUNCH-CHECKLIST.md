# GuardRail Launch Checklist

## Pre-Launch (do these first)

- [ ] Record terminal GIF: `guardrail init` + `guardrail pentest` (for Product Hunt, Dev.to)
- [ ] Capture 5 screenshots (see Product Hunt file for list)
- [ ] Ensure GitHub README is current (star count, badges working)
- [ ] Verify landing page loads: https://guardrail.promptandbuild.de
- [ ] Verify npm install works: `npx guardrail-agent init` on a clean machine
- [ ] Verify trial works: `guardrail upgrade --trial` downloads and installs
- [ ] Prepare a personal GitHub account comment reply template for follow-up questions

## Launch Day 1 (Tuesday, best day for HN/PH)

**Morning (08:00-09:00 UTC):**
1. [ ] Post on Hacker News (Show HN) - file: `hacker-news-show-hn.md`
   - Post between 08:00-09:00 UTC for US morning visibility
   - Monitor and reply to comments for the first 2-3 hours (critical for ranking)

**Afternoon (14:00 UTC):**
2. [ ] Post on r/ClaudeAI - file: `reddit-claudeai.md`
   - Reddit is timezone-agnostic but US afternoon peaks
   - Reply to every comment within 1 hour

## Launch Day 2 (Wednesday)

**Morning:**
3. [ ] Publish Dev.to article - file: `devto-article.md`
   - Add the terminal GIF at the top
   - Cross-post to Hashnode if account exists
   - Share the Dev.to link on Twitter/X

**Afternoon:**
4. [ ] Post on IndieHackers - file: `indiehackers.md`
   - IH audience cares about revenue transparency, respond to pricing feedback

## Launch Day 3 (Thursday)

5. [ ] Product Hunt launch - file: `product-hunt-launch.md`
   - Schedule for 00:01 PST (best for full-day visibility)
   - Post the First Comment immediately after launch
   - Share PH link on LinkedIn, Twitter, Reddit (cross-promote)
   - Reply to every comment and upvote

## Post-Launch (Week 1)

- [ ] Write a follow-up post on whatever platform got the most traction
- [ ] If HN hit front page: write a "What I learned from launching on HN" post for IH
- [ ] Collect feedback themes and create GitHub issues for requested features
- [ ] Track: npm downloads delta, GitHub stars delta, trial starts, landing page visits
- [ ] Add social proof (star count, download count) to landing page if numbers grew

## Metrics to Track

| Platform | Baseline | Post-Launch Target |
|----------|----------|-------------------|
| npm downloads/month | 1,537 | 5,000+ |
| GitHub stars | check current | +200 |
| Trial starts (via admin notifications) | 0 | 50+ |
| Landing page visits (Umami) | unknown | 1,000+ |
| Pro subscriptions | 0 | 5+ |
| Starter Kit sales | 0 | 3+ |

## Platform-Specific Notes

**Hacker News:**
- Title must include "Show HN:" prefix
- No tracking links, use raw URLs
- Don't ask for upvotes (instant penalty)
- Be technical, be honest, answer criticism directly
- If it gains traction, stay engaged for 4-6 hours

**Reddit r/ClaudeAI:**
- No self-promotion framing. Lead with the problem, not the product
- Flair: check subreddit rules for correct flair
- Don't post GitHub/website links in the first line (spam filter)

**Product Hunt:**
- Needs a hunter (someone else to submit) for better visibility. If none available, self-submit
- Gallery images: minimum 3, maximum 8. Mix of screenshots and diagrams
- Respond to every review within 24 hours

**Dev.to:**
- Use cover image (terminal screenshot or architecture diagram)
- Tags: security, ai, opensource, tutorial (max 4)
- Add a series if planning follow-up articles

**IndieHackers:**
- Revenue transparency is the currency. Be specific about numbers
- Ask genuine questions at the end (not rhetorical)
- Follow up with a revenue update post in 30 days
