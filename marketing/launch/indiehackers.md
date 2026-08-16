# IndieHackers Post

## Title
I built a security tool for AI coding agents. 1,537 npm downloads/month, 0 revenue. Here's the plan.

## Body

**What I built:** GuardRail is a set of bash scripts that intercept and block dangerous commands before AI coding agents (Claude Code, Cursor, etc.) can execute them. Think of it as a firewall between the AI and your terminal.

**The numbers (transparent):**
- 1,537 npm downloads/month
- 2 test licenses sold (both by me testing the payment flow)
- 0 EUR actual revenue
- 92 EUR/month server costs

**The irony:** I built GuardRail using AI agents that are protected by GuardRail. The tool's own development has been its longest-running test case, 14 months on a production server with 13 apps and 24 databases. 177 guard rules, blocking about 1,400 dangerous operations per week.

**What went wrong with monetization:**

For months, the free version worked great and the paid version had no path to it. No trial, no upsell in the CLI, no friction-free way to go from "this is useful" to "I'll pay for more." 1,537 people install it every month and then... nothing.

This week I fixed that:

1. Added `guardrail upgrade --trial` to the CLI, downloads 48 Pro guards free for 14 days, no credit card, no signup
2. Added upsell touchpoints at the moments where users see the most value (after `guardrail pentest` shows what the 20 free guards catch, it says "but real attacks use multi-step patterns")
3. Created an AI Governance Starter Kit (69 EUR one-time), a curated package of guards, hooks, and runbooks for teams adopting AI agents
4. Built the landing page and Stripe checkout flow

**The product ladder I'm building:**
- Free: 20 core guards (npm install, MIT licensed)
- Starter Kit: 69 EUR one-time (pre-packaged guard system)
- Pro: 29 EUR/month (48 guards, compliance reports)
- Masterclass: 399 EUR one-time (30 lessons, masterclass.promptandbuild.de)

**Target: 10,000 EUR/month passive income.** No consulting, no workshops, no hourly billing. Just products that sell while I sleep.

**What I'd love feedback on:**
1. Is the free-to-trial-to-paid flow convincing? Would you try the trial after seeing the pentest results?
2. Is 29 EUR/month too much, too little, or right for a security tool that protects your AI agent operations?
3. Would you pay 69 EUR for a pre-packaged governance starter kit, or would you rather build your own from the free guards?

GitHub: https://github.com/FvdHMBAI/guardrail
Website: https://guardrail.promptandbuild.de
npm: npx guardrail-agent init
