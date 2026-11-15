# Agents inside our apps: the north star

A reference to open when designing or changing an agent that lives inside one of our apps. Nothing loads it
automatically.

## The idea

A person can ask the agent for anything they could do in the app themselves, and the agent does it the same way
they would: through the same operations, under the same permissions, leaving the same record.

```
                 ┌──────────────────────── the app ────────────────────────┐
 person ─► panel │  one loop ─► tools ─► the same operations the screens use │
                 │                         reads run directly                │
                 │                         writes become a proposal          │
                 └───────────────────────────────────────────────────────────┘
                              proposal ─► card ─► the person clicks ─► the operation runs ─► receipt
```

The agent adds no rules of its own. It is a second way to reach what the app already does.

## What every agent has

**One loop.** One model, one conversation, one set of tools. A new place to talk to the agent (Slack, an outside
client, an external user) gets a shorter list of tools over the same loop. It never gets a loop of its own.

**Tools that only connect.** A tool calls the operation the screen calls, with the same input checks and the same
permission check. When the operation refuses, the tool passes on the operation's own reason. A tool that carries
its own copy of a check will drift from the real one, and the agent will start refusing things the app allows.

**Few tools.** A handful of broad reads ("everything about this case") and one write per real command. When the
list grows, merge tools before adding machinery to search them.

**Writes the person approves, once.**

```
agent proposes ─► stored proposal ─► card shows what will change ─► click ─► runs once ─► stored result
     │                                    (computed by the operation,          │
     └─ refused by the app? say so,        never described by the model)       └─ the card shows the result;
        no card                                                                   the model is not involved
```

One card per thing the person asked for, not one per field. The agent saying "yes" approves nothing. The model
does not run between the proposal and the result.

**A turn the server owns.** The browser sends only the new message. The server holds the conversation, runs one
turn at a time, and finishes the turn even if the tab closes.

**A beginning that never changes.** The instructions and the tool list are the same on every turn, so they are
cached and cheap. Whatever varies (today's date, the page, the record) is added after them as a message. The
instructions never restate a business rule: the agent learns the rule from the app's answer.

**A spending limit that holds.** Each person has a daily limit in money, and each turn has a ceiling. Over the
limit, the agent says so and stops.

**No way out for data.** Text from documents is marked as evidence, not instructions, but marking only lowers the
risk. What holds is the surroundings: the agent acts as the signed-in person and has no tool, link or image that
can send data elsewhere.

**Nothing extra until it is needed.** Summarising long conversations, a second model provider, tool search, helper
agents, memory across conversations: each waits until we have seen the problem it solves, and goes when it stops
earning its place.

**Small checks on outcomes.** Ten to twenty real scenarios, judged on what ended up in the app, run when the model
or the instructions change. Never judged on the agent's wording.

## The three kinds of app we have

What decides an agent's shape is where the app keeps its working truth.

```
 records on the server          live operations on the server        a live draft in the browser
 (MO)                           (procurement)                        (Pricing)

 each change is saved           each change is a backend function    every keystroke recalculates a draft
 as it happens                  the screens subscribe to             that is saved only on submit

 tool ─► the same function      tool ─► the same backend function    tool ─► runs in the browser on the draft
 in the same process            over the wire                        then the turn continues in a new request

 thinnest agent                 thin, if each function supplies      heaviest agent, and rightly so
                                its own preview and refusal
```

**Records on the server (MO).** The simple case: follow everything above as written. Keep it simple by never
moving working state into the browser.

**Live operations on the server (procurement).** The same shape, with one trap. Because tools reach operations
over the wire, it is tempting to build a layer in between that prepares previews and pre-checks each write. That
layer becomes a second copy of the rules. Each operation should supply its own preview and its own refusal, and
the layer in between should only store the proposal and run it once.

**A live draft in the browser (Pricing).** The draft is the truth until submit, and it has to answer instantly, so
it stays in the browser and the agent's writes run there too. Each write ends the server's part of the turn, the
browser applies it, and a new request carries on. This costs more code and is the right choice for this kind of
screen. Do not move the draft to the server to make the agent simpler. Everything else still holds: one loop,
tools that call what the form calls, few tools, the unchanging beginning, the spending limit, nothing extra.

## Questions to ask of any agent change

1. Does this tool call exactly what the screen calls, or did it grow logic of its own?
2. Could the app refuse this after the person clicks? Then it should have refused before the card.
3. Does the card show what the operation computed, or what the model said?
4. What happens on a double click, a closed tab, a second tab?
5. Did anything that varies sneak into the unchanging beginning?
6. Is this new machinery answering a problem we have seen, or one we imagine?
