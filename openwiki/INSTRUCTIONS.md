---
type: Repository guide
title: Courier wiki instructions
description: Brief that steers how OpenWiki writes and maintains the Courier documentation for both non-technical and developer readers.
tags: [documentation, overview, operations]
---

# OpenWiki brief for Courier

## What this wiki is for

Courier is Cruise Control's messaging inbox for dealership staff. It is a fork of the
open-source Chatwoot project with Cruise Control features added on top. Two audiences read this
wiki, and every page must work for both:

1. **Non-technical readers** (product managers, sales, executives, customer success). They ask
   things like "What happens when a shopper comments on a dealership's Facebook post?", "When
   does Stark stop replying and hand a conversation to a person?", "How are leads attributed to
   an ad or campaign?", "What do the booking stats report show?", "How do we block a customer?".
2. **Developers**, including people new to the codebase. They ask "Where is the Stark webhook
   handled?", "Which job sends a template DM?", "How does the Enterprise overlay override core
   code?", "How do I run the specs?", "What does the release pipeline do?".

## Writing rules

- Start every page with a 2 to 4 sentence plain-English summary that a non-engineer can read
  without knowing what a class or endpoint is. Put file paths, class names and method
  signatures in a later "For developers" section on the same page.
- State on every page whether the feature is **upstream Chatwoot**, **a Cruise Control
  addition**, or **Chatwoot behaviour changed by Cruise Control**. Give Cruise Control
  additions and changes more depth; describe untouched upstream features briefly and accurately.
- Prefer numbered step-by-step flows ("1. A shopper sends a WhatsApp message. 2. Courier creates
  the conversation. 3. ...") over long prose. Name the concrete file or class in parentheses at
  the end of each step so developers can jump in.
- Always state the business consequence of a behaviour: a conversation is opened or resolved,
  Stark replies, a human is alerted, a booking is recorded, a lead is attributed, a message is
  blocked.
- Use the glossary terms below consistently. Define acronyms on first use on every page.
- Prefer tables over diagrams. If a Mermaid diagram is used, precede it with a text description
  of the same flow, because chat clients often do not render Mermaid.
- Never reproduce secrets, tokens, API keys, hostnames, IP addresses, email addresses, Slack
  channel IDs, SSH details or credentials, even from example, docs or CI files. Describe
  environment variables by purpose, not by value. Do not name real dealerships or customers.
- Do not quote outbound message, email or template copy verbatim. Summarise what it says and
  when it is sent.
- Ruby code under `enterprise/` extends or overrides code under `app/` and `lib/` (via
  `prepend_mod_with` / `include_mod_with`). When documenting a feature, mention the Enterprise
  override if one exists.
- Front matter on every page must include `type`, `title`, a one-sentence `description`, and
  `tags` (2 to 6 lowercase items from the vocabulary below). Keep `tags` as a flat inline list.

## Tag vocabulary

overview, accounts, agents, inboxes, channels, conversations, contacts, messages, stark,
pressroom, chatwoot, enterprise, facebook, instagram, whatsapp, sms, email, widget, leads,
attribution, bookings, vehicles, offers, blocklist, escalations, automation, reports,
notifications, integrations, analytics, api, frontend, sidekiq, operations, deployment,
configuration, testing

## Glossary of Courier business concepts

- **Courier**: Cruise Control's messaging inbox, used by dealership staff to talk to shoppers
  across channels. Built on Chatwoot.
- **Chatwoot**: the open-source customer-support inbox Courier is forked from. Most of the
  codebase is upstream Chatwoot.
- **Cruise Control**: the company and platform Courier belongs to.
- **Stark**: Cruise Control's AI sales assistant. Courier forwards shopper messages to Stark as
  an agent bot and posts Stark's replies back into the conversation (`lib/integrations/stark/`,
  `app/services/stark/`).
- **Pressroom**: Cruise Control's dealership-data platform. It creates conversations, messages
  and private notes in Courier (for example for inbound leads) through the Courier API.
- **Account**: the tenant, normally one dealership. Holds inboxes, agents, settings, the AI bot
  name and avatar, and feature flags.
- **Inbox / channel**: one connected messaging source (website widget, Facebook, Instagram,
  WhatsApp, SMS, email, API).
- **Conversation**: a thread between a shopper and the dealership in one inbox, with a status
  (open, pending, resolved, snoozed), labels and an assignee.
- **Contact**: a shopper, with their channels and lead attribution (which ad, campaign or origin
  brought them).
- **Agent / agent bot**: a human staff member, or an automated bot (such as Stark) that replies
  in conversations.
- **Handoff / escalation**: when Stark or a rule passes a conversation to a human, including
  department-wise escalation to the right team.
- **Facebook comments and lead forms**: replies, likes and DMs on dealership posts, and leads
  captured through Facebook lead forms, turned into Courier conversations.
- **Template message**: a pre-approved WhatsApp, Facebook or Instagram message used to start or
  resume a conversation outside the free-reply window.
- **Booking**: an appointment (test drive, visit, call) created from a conversation, with
  booking stats and summaries in reports.
- **Vehicle**: a unit from a dealership's inventory shown to shoppers, with vehicle-detail
  visit reports.
- **Offers and promotions**: dealership deals managed in Courier and quoted to shoppers.
- **Blocked conversation / blocklist**: a shopper the dealership no longer wants to message.
- **Super Admin**: the installation-wide admin console (accounts, default templates, config).
