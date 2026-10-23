# 0003 — Rolling cleanup during speech

**Status:** proposed · 2026-10-23

## Context

A single LLM cleanup pass after release adds its full latency to every utterance. Self-corrections ("Friday, no wait, Thursday") can span pauses.

## Decision

Cleanup runs on each ASR-committed segment while the user is still speaking, given the previous cleaned segment as context and allowed to rewrite it. On release only the tail segment is cleaned. Utterances that pass a cheap "already clean" check skip the LLM.

## Consequences

Post-release cleanup cost becomes roughly one short segment. Needs streaming ASR with stable commits, and the client must accept a final that differs from earlier partials.
