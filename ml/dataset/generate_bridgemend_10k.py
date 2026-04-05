"""
Build bridgemend_dataset_10000.csv from the same 10 counseling scenarios as the 1k set.

Each scenario gets 1,000 combinatorial user-message paraphrases and a larger response pool
derived from the original two replies per theme. Run once to regenerate the CSV.

Usage:
  cd ml/dataset
  python generate_bridgemend_10k.py
"""

from __future__ import annotations

import csv
import itertools
from pathlib import Path


def _take_n(product_iter, n: int):
    return list(itertools.islice(product_iter, n))


def _input_output(user: str, assistant: str) -> str:
    return f"Input: {user} || Output: {assistant}"


def build_rows() -> list[dict]:
    rows: list[dict] = []
    sid = 1

    scenarios = [
        _scenario_ignored(),
        _scenario_defensive(),
        _scenario_recurring(),
        _scenario_stress(),
        _scenario_excluded(),
        _scenario_better_comm(),
        _scenario_nostalgia(),
        _scenario_dominate(),
        _scenario_anxious(),
        _scenario_listen_rule(),
    ]

    for gen in scenarios:
        for item in gen:
            rows.append(
                {
                    "session_id": f"BM{sid:05d}",
                    "session_type": item["session_type"],
                    "speaker": item["speaker"],
                    "input_text": item["input_text"],
                    "emotion": item["emotion"],
                    "conflict_type": item["conflict_type"],
                    "response_type": item["response_type"],
                    "privacy_level": item["privacy_level"],
                    "ai_response": item["ai_response"],
                    "input_output": _input_output(item["input_text"], item["ai_response"]),
                }
            )
            sid += 1

    return rows


def _scenario_ignored():
    st, sp, em, cf, rt, pr = (
        "personal",
        "husband",
        "sadness",
        "communication gap",
        "empathy",
        "personal",
    )
    a = [
        "I feel",
        "I've been feeling",
        "It hurts when",
        "I struggle when",
        "Lately I feel",
        "Sometimes I feel",
        "I'm drained because",
        "I get discouraged when",
        "I'm upset because",
        "Honestly,",
    ]
    b = [
        "she doesn't really listen",
        "she seems checked out",
        "my words don't seem to land",
        "I don't feel heard",
        "she tunes me out",
        "she interrupts before I'm done",
        "she dismisses what I say",
        "I can't get through",
        "she looks away mid-sentence",
        "she changes the subject fast",
    ]
    c = [
        "when I try to explain.",
        "during serious talks.",
        "about how I feel.",
        "when we disagree.",
        "about us.",
        "when I open up.",
        "in deeper conversations.",
        "when I need support.",
        "before I finish my thought.",
        "when I'm vulnerable.",
    ]
    responses = [
        "Feeling ignored can hurt. Ask for a calm moment and state one specific need.",
        "It sounds like you feel unheard. Try expressing your needs calmly and clearly.",
        "Being overlooked is painful. Request a short pause and share one concrete need.",
        "Your experience matters. Name one feeling and one request in a gentle tone.",
        "Hurt here makes sense. Invite her to listen for two minutes without fixing.",
        "Unheard feelings build resentment. Try a soft start: one feeling, one need.",
        "This is valid. Ask when a better time is and keep your message brief.",
        "You deserve to be listened to. Use an I-statement and one clear ask.",
        "Pause the spiral. Say you want to feel understood before solving.",
        "Try naming the impact: when I'm interrupted, I feel dismissed.",
        "Pick a calm window. Say you'd like five minutes to finish a thought.",
        "Reflect what you want: understanding first, solutions second.",
        "Keep one topic. Avoid blame labels; describe the pattern you notice.",
        "Ask for a repair: a simple apology for the tone can reopen the talk.",
        "If volume rises, suggest a ten-minute break and return with one agenda item.",
    ]
    for i, parts in enumerate(_take_n(itertools.product(a, b, c), 1000)):
        u = f"{parts[0]} {parts[1]} {parts[2]}".replace("  ", " ").strip()
        yield {
            "session_type": st,
            "speaker": sp,
            "emotion": em,
            "conflict_type": cf,
            "response_type": rt,
            "privacy_level": pr,
            "input_text": u,
            "ai_response": responses[i % len(responses)],
        }


def _scenario_defensive():
    st, sp, em, cf, rt, pr = (
        "personal",
        "wife",
        "frustration",
        "defensive behavior",
        "reflection",
        "personal",
    )
    a = [
        "He gets defensive",
        "He shuts down and gets defensive",
        "He becomes defensive",
        "My partner gets defensive",
        "He reacts defensively",
        "Whenever I bring things up he gets defensive",
        "He goes straight to defense",
        "I see defensiveness quickly",
        "He bristles the moment I raise an issue",
        "Defensiveness shows up before I've finished",
    ]
    b = [
        "and I stop sharing.",
        "so I pull back.",
        "and I go quiet.",
        "and I avoid hard topics.",
        "and I end the conversation.",
        "and I feel unsafe to continue.",
        "and I retreat.",
        "and I lose hope mid-talk.",
        "and I stuff my feelings.",
        "and I wonder if it's worth speaking.",
    ]
    c = [
        "",
        " It repeats often.",
        " This is our cycle.",
        " Same pattern weekly.",
        " It happened again last night.",
        " I'm exhausted by it.",
        " I want a different dynamic.",
        " We both deserve better.",
        " I don't know how to break it.",
        " Even small topics trigger it.",
        " I still love him; this part is hard.",
    ]
    responses = [
        "You are noticing a pattern that blocks sharing. Pause and reset the tone before continuing.",
        "This pattern suggests tension. Try choosing a calmer time to talk.",
        "Defensiveness often signals threat. Soften your opening; ask for curiosity first.",
        "Name the pattern without attacking character. Focus on impact, not intent.",
        "Try a repair bid: I want us to stay on the same team.",
        "Invite a slower pace: one concern at a time, with breaks if needed.",
        "Ask what would help him feel safe enough to listen.",
        "Share one observation and one request; avoid a list of grievances.",
        "Consider timing: avoid late night or post-work spikes.",
        "Reflect what you need: validation, a plan, or space?",
        "Use gentle startup language; harsh openings trigger defense.",
        "If he escalates, pause and agree to return in thirty minutes.",
        "Acknowledge any fair point he has; it lowers defensiveness.",
        "Ask for a do-over when tone derails the message.",
        "Keep the goal visible: understanding today, solutions tomorrow.",
    ]
    for i, parts in enumerate(_take_n(itertools.product(a, b, c), 1000)):
        u = f"{parts[0]} {parts[1]}{parts[2]}".replace("  ", " ").strip()
        yield {
            "session_type": st,
            "speaker": sp,
            "emotion": em,
            "conflict_type": cf,
            "response_type": rt,
            "privacy_level": pr,
            "input_text": u,
            "ai_response": responses[i % len(responses)],
        }


def _scenario_recurring():
    st, sp, em, cf, rt, pr = (
        "couple",
        "both",
        "frustration",
        "recurring conflict",
        "de-escalation",
        "shared",
    )
    a = [
        "We keep arguing",
        "We circle the same fight",
        "We return to the same argument",
        "The same issue keeps resurfacing",
        "We replay the same conflict",
        "We can't move past this topic",
        "This argument loops",
        "We get stuck on the same theme",
        "The fight reboots every few days",
        "We predict the script before it starts",
    ]
    b = [
        "about the same issue.",
        "every week.",
        "without resolution.",
        "and it exhausts us.",
        "and nothing changes.",
        "though we both want peace.",
        "even when we try to stop.",
        "and it erodes trust.",
        "until we're both depleted.",
        "and we lose whole evenings to it.",
    ]
    c = [
        "",
        " We need a new approach.",
        " It feels hopeless sometimes.",
        " We want tools.",
        " Can we interrupt this pattern?",
        " Neither of us likes this.",
        " We're stuck in a loop.",
        " Small things become huge.",
        " Old wounds keep returning.",
        " We need a reset.",
    ]
    responses = [
        "Slow the discussion and let each person speak fully before responding.",
        "This seems repeated. Focus on one issue and avoid past topics for now.",
        "Name the cycle together. Agree on a pause word when volume rises.",
        "Take turns: two minutes each, then summarize what you heard.",
        "Table side topics; bookmark them for Saturday morning.",
        "Ask what each person needs before debating facts.",
        "Lower the temperature: lower voice, slower pace, seated posture.",
        "Pick one solvable slice instead of the whole history.",
        "End with one experiment for the week, not ten fixes.",
        "If flooded, break for twenty minutes and return with one agenda item.",
        "Validate the emotion under the complaint before problem-solving.",
        "Avoid mind-reading; ask clarifying questions instead.",
        "Use a shared doc for recurring themes to reduce surprise attacks.",
        "Celebrate small wins when you interrupt the old loop.",
        "Consider a therapist if safety or contempt shows up often.",
    ]
    for i, parts in enumerate(_take_n(itertools.product(a, b, c), 1000)):
        u = f"{parts[0]} {parts[1]}{parts[2]}".replace("  ", " ").strip()
        yield {
            "session_type": st,
            "speaker": sp,
            "emotion": em,
            "conflict_type": cf,
            "response_type": rt,
            "privacy_level": pr,
            "input_text": u,
            "ai_response": responses[i % len(responses)],
        }


def _scenario_stress():
    st, sp, em, cf, rt, pr = (
        "personal",
        "husband",
        "guilt",
        "stress spillover",
        "accountability coaching",
        "personal",
    )
    a = [
        "Work stress made me speak harshly.",
        "Job pressure spilled into how I spoke.",
        "I snapped because work drained me.",
        "Stress from work made my tone sharp.",
        "I was harsh after a brutal workday.",
        "My workload leaked into our argument.",
        "I took work frustration out on the conversation.",
        "I was short-tempered after stressful meetings.",
        "Deadlines made me sharp at home.",
        "I brought office tension into our talk.",
    ]
    b = [
        "",
        " I regret it.",
        " I want to repair.",
        " I'm ashamed after.",
        " I see the impact on us.",
        " I don't want that pattern.",
        " I need better coping tools.",
        " I'm working on it.",
        " I hate that I did that.",
        " My partner deserved better in that moment.",
    ]
    c = [
        "",
        " It isn't fair to my partner.",
        " I want to own my tone.",
        " I need a reset ritual after work.",
        " I want to separate job stress from us.",
        " I'm asking for patience as I learn.",
        " I know tone matters.",
        " I don't want excuses.",
        " I'm open to feedback.",
        " I want to practice repair.",
    ]
    d = [
        "",
        " Help me reset faster.",
        " What should I try tonight?",
        " I need concrete steps.",
    ]
    responses = [
        "Acknowledge the tone, apologize, and commit to a calmer response next time.",
        "Recognize your part and plan how to manage stress before conversations.",
        "Name the behavior, apologize specifically, and ask what repair would help.",
        "Create a transition ritual after work: walk, shower, ten-minute buffer.",
        "Warn when you're depleted: I'm on edge; can we talk in an hour?",
        "Practice a one-sentence repair when you slip: I spoke harshly; I'm sorry.",
        "Separate work venting from relationship talks when possible.",
        "If flooded, call a pause before you say something cutting.",
        "Ask your partner what tone signals care to them.",
        "Track triggers: sleep, caffeine, deadlines—reduce when you can.",
        "Commit to one repair action this week you can measure.",
        "Gratitude plus accountability rebuilds trust faster than excuses.",
        "Consider short counseling if stress stays chronic and harmful.",
        "Use I-language about stress without blaming your partner for your job.",
        "End with a clear next step: I'll text when I'm regulated.",
    ]
    for i, parts in enumerate(_take_n(itertools.product(a, b, c, d), 1000)):
        u = " ".join(p for p in parts if p).strip()
        u = u.replace("  ", " ").replace(". .", ".").strip()
        if u.endswith(".."):
            u = u[:-1]
        yield {
            "session_type": st,
            "speaker": sp,
            "emotion": em,
            "conflict_type": cf,
            "response_type": rt,
            "privacy_level": pr,
            "input_text": u,
            "ai_response": responses[i % len(responses)],
        }


def _scenario_excluded():
    st, sp, em, cf, rt, pr = (
        "personal",
        "wife",
        "hurt",
        "trust issue",
        "validation",
        "personal",
    )
    a = [
        "I feel excluded from important decisions.",
        "I'm left out of major choices.",
        "Decisions happen without me.",
        "I learn about plans after they're made.",
        "I don't get included in financial talks.",
        "Big moves are decided solo.",
        "My input isn't sought on priorities.",
        "I feel sidelined in our life planning.",
        "I'm finding out after the fact too often.",
        "Joint decisions feel one-sided lately.",
    ]
    b = [
        "",
        " It hurts.",
        " I feel small.",
        " I want partnership.",
        " I'm losing trust.",
        " I need transparency.",
        " I want to feel like a teammate.",
        " I'm not asking to control everything.",
        " I want a voice in our future.",
        " This pattern scares me.",
    ]
    c = [
        "",
        " Can we fix this?",
        " What should I say?",
        " How do I bring it up calmly?",
        " I don't want a fight.",
        " I need a script.",
        " Where do we start?",
        " I want hope here.",
        " Can we rebuild this?",
        " I believe we can do better.",
    ]
    responses = [
        "Feeling excluded is valid. Explain why shared decisions matter to you.",
        "Your concern is understandable. Ask for regular check-ins on decisions.",
        "Name the impact clearly without accusing motive.",
        "Request a standing agenda slot for joint decisions monthly.",
        "Ask what information you need to feel included.",
        "Propose a simple rule: no big spends without a ten-minute chat.",
        "Validate their competence while asking for collaboration.",
        "If safety is the issue, clarify what would increase trust.",
        "Use a shared calendar and decision log to reduce surprises.",
        "Seek couples counseling if secrecy or control patterns persist.",
        "Ask for a repair conversation focused on process, not blame.",
        "Celebrate when they loop you in; reinforcement helps habits.",
        "Be specific: I want to co-decide on X and Y.",
        "Listen for their fears about slowing decisions down.",
        "End with one trial week of a new check-in habit.",
    ]
    for i, parts in enumerate(_take_n(itertools.product(a, b, c), 1000)):
        u = " ".join(p for p in parts if p).strip()
        u = u.replace("  ", " ").strip()
        yield {
            "session_type": st,
            "speaker": sp,
            "emotion": em,
            "conflict_type": cf,
            "response_type": rt,
            "privacy_level": pr,
            "input_text": u,
            "ai_response": responses[i % len(responses)],
        }


def _scenario_better_comm():
    st, sp, em, cf, rt, pr = (
        "couple",
        "both",
        "hope",
        "none",
        "positive reinforcement",
        "shared",
    )
    a = [
        "We want to communicate better.",
        "We're trying to improve how we talk.",
        "We hope to listen more kindly.",
        "We want fewer blowups.",
        "We're committed to better dialogue.",
        "We'd like calmer check-ins.",
        "We want teamwork in conversations.",
        "We're working on respectful talk.",
        "We want repair skills, not perfection.",
        "We're ready to practice daily habits.",
    ]
    b = [
        "",
        " Where do we start?",
        " Small steps help us.",
        " We need practical ideas.",
        " We're motivated.",
        " It's our priority.",
        " We're tired of hurting each other.",
        " We love each other and want tools.",
        " We argue less when we're rested.",
        " We want to model kindness.",
    ]
    c = [
        "",
        " Can you guide us?",
        " We need a simple plan.",
        " One habit at a time works.",
        " We have twenty minutes a day.",
        " We want homework we can do.",
        " No jargon, please.",
        " We're beginners at this.",
        " We'll celebrate small wins.",
        " We want this to last.",
    ]
    responses = [
        "Great goal. Practice active listening and end with one action step.",
        "Build on this by checking in regularly and keeping respect.",
        "Pick one skill weekly: paraphrase before you respond.",
        "Use daily five-minute appreciations to bank goodwill.",
        "Agree on a pause signal and honor it without chasing.",
        "Keep phones away for focused talks.",
        "End conflict talks with appreciation for effort, not just outcome.",
        "Schedule a weekly state-of-us chat, even ten minutes.",
        "Read one short resource together and discuss one takeaway.",
        "Celebrate progress loudly; new habits need reinforcement.",
        "If stuck, a few sessions with a therapist can accelerate skills.",
        "Model curiosity: what did you mean by that?",
        "Avoid scorekeeping; focus on today's conversation.",
        "Use soft eyes and slower speech when tension rises.",
        "Finish with: what is one thing we did well today?",
    ]
    for i, parts in enumerate(_take_n(itertools.product(a, b, c), 1000)):
        u = " ".join(p for p in parts if p).strip()
        u = u.replace("  ", " ").strip()
        yield {
            "session_type": st,
            "speaker": sp,
            "emotion": em,
            "conflict_type": cf,
            "response_type": rt,
            "privacy_level": pr,
            "input_text": u,
            "ai_response": responses[i % len(responses)],
        }


def _scenario_nostalgia():
    st, sp, em, cf, rt, pr = (
        "personal",
        "husband",
        "nostalgia",
        "relationship distance",
        "bonding suggestion",
        "personal",
    )
    a = [
        "I miss how we used to talk calmly.",
        "I miss easy conversations with you.",
        "We used to laugh more together.",
        "I long for the gentler tone we had.",
        "I miss feeling close when we talk.",
        "I remember softer evenings together.",
        "I miss low-drama chats.",
        "I miss feeling like teammates daily.",
        "I miss playful banter between us.",
        "I miss feeling chosen and safe.",
    ]
    b = [
        "",
        " Can we find that again?",
        " I don't know how to restart.",
        " It feels far away now.",
        " I want that warmth back.",
        " I'm grieving the ease we had.",
        " I believe it's possible again.",
        " I don't want to pressure you.",
        " I want to co-create something new.",
        " I'm willing to be patient.",
    ]
    c = [
        "",
        " Small steps would help.",
        " I'm hopeful but scared.",
        " What would you suggest?",
        " I need ideas.",
        " I want a gentle path.",
        " Can we try one ritual?",
        " I want to lead with love.",
        " I'm afraid of rejection.",
        " I still care deeply.",
    ]
    responses = [
        "Share a positive memory to reopen safe communication.",
        "Plan a calm activity together to rebuild connection.",
        "Name one small ritual to revive: walk, coffee, no-phones dinner.",
        "Lead with appreciation before raising problems.",
        "Ask what connection looked like for them, not only for you.",
        "Lower pressure: aim for pleasant, not perfect.",
        "Try a gratitude exchange three nights a week.",
        "Repair recent hurts briefly so nostalgia can land.",
        "Schedule fun first, problem-solving second.",
        "Touch base midday with a kind text to rebuild warmth.",
        "If distance is long-standing, consider guided support.",
        "Share a song or photo that reminds you of good times.",
        "Invite a curiosity question: what made you feel loved last month?",
        "Protect sleep; tired couples hear threats louder.",
        "End tonight with one sentence about what you cherish.",
    ]
    for i, parts in enumerate(_take_n(itertools.product(a, b, c), 1000)):
        u = " ".join(p for p in parts if p).strip()
        u = u.replace("  ", " ").strip()
        yield {
            "session_type": st,
            "speaker": sp,
            "emotion": em,
            "conflict_type": cf,
            "response_type": rt,
            "privacy_level": pr,
            "input_text": u,
            "ai_response": responses[i % len(responses)],
        }


def _scenario_dominate():
    st, sp, em, cf, rt, pr = (
        "couple",
        "both",
        "frustration",
        "communication imbalance",
        "pattern reflection",
        "shared",
    )
    a = [
        "One of us dominates the conversation.",
        "Talk time feels uneven between us.",
        "I do most of the talking and it bothers us.",
        "My partner hogs the airtime.",
        "We interrupt each other constantly.",
        "One voice overpowers the other.",
        "We don't get equal space to share.",
        "Monologues replace dialogue.",
        "We talk over each other without meaning to.",
        "Listening feels one-sided lately.",
    ]
    b = [
        "",
        " It's frustrating.",
        " We both notice it.",
        " How do we balance?",
        " We want fairness.",
        " Neither of us feels fully heard.",
        " We want a simple rule.",
        " We spiral when this happens.",
        " We need a reset button.",
        " We want equity, not scorekeeping.",
    ]
    c = [
        "",
        " Please suggest tools.",
        " We need structure.",
        " Concrete steps help.",
        " We're willing to practice.",
        " Ten minutes each would feel fair.",
        " We want a timer if needed.",
        " We need language that isn't blaming.",
        " We want teamwork.",
        " We'll try for a week.",
    ]
    responses = [
        "Balance speaking time and reflect what you heard before replying.",
        "Use turn-taking to make the conversation fair.",
        "Try a timer: two minutes each, then swap.",
        "Use a talking object; only holder speaks.",
        "Reflect back before adding your point.",
        "Name the pattern kindly: we both want to be heard.",
        "Agree on a signal when someone exceeds their share.",
        "Prioritize curiosity questions over statements.",
        "If one is quieter, invite specifics: what would help you open up?",
        "Write bullet points first to reduce ramble.",
        "Close loops: did you feel understood before moving on?",
        "Practice the five-second pause after they finish.",
        "If anxiety drives overtalking, name it and slow breath together.",
        "Celebrate balanced talks; note what helped.",
        "Seek help if contempt or dismissal appears when the quieter speaks.",
    ]
    for i, parts in enumerate(_take_n(itertools.product(a, b, c), 1000)):
        u = " ".join(p for p in parts if p).strip()
        u = u.replace("  ", " ").strip()
        yield {
            "session_type": st,
            "speaker": sp,
            "emotion": em,
            "conflict_type": cf,
            "response_type": rt,
            "privacy_level": pr,
            "input_text": u,
            "ai_response": responses[i % len(responses)],
        }


def _scenario_anxious():
    st, sp, em, cf, rt, pr = (
        "personal",
        "wife",
        "anxiety",
        "anger escalation",
        "calming strategy",
        "personal",
    )
    a = [
        "Arguments make me anxious.",
        "Raised voices spike my anxiety.",
        "Conflict shuts my body down.",
        "I panic when we fight.",
        "My chest tightens during disagreements.",
        "I freeze when tension rises.",
        "Fighting triggers my worry loop.",
        "I feel unsafe when we escalate.",
        "My thoughts race when we disagree.",
        "I shut down but I still care.",
    ]
    b = [
        "",
        " I need grounding tips.",
        " How do I stay present?",
        " I hate feeling this way.",
        " I want to stay engaged calmly.",
        " I don't want to flee every time.",
        " I want skills, not shame.",
        " My body goes into alarm.",
        " I need compassion and tools.",
        " I want my partner to understand.",
    ]
    c = [
        "",
        " Please help me regulate.",
        " Small steps matter.",
        " What can I do in thirty seconds?",
        " I need phrases to say.",
        " I want to co-regulate with them.",
        " I need a pause plan.",
        " I'm willing to practice daily.",
        " I want hope.",
        " I believe we can improve.",
    ]
    responses = [
        "Take a short pause and use slow breathing before continuing.",
        "Ask for a break if the tone escalates.",
        "Name your nervous system need: slower pace, lower volume, seated talk.",
        "Try box breathing for ninety seconds before responding.",
        "Ground with five things you see and four you hear.",
        "Agree on a safe word for timeouts.",
        "Keep water nearby; sip to slow your speech.",
        "If dissociation hits, orient: feet on floor, name the date.",
        "Share your anxiety label so your partner doesn't misread withdrawal.",
        "Pair repair with self-compassion after tough talks.",
        "Consider therapy for trauma if panic is severe.",
        "Limit conflict length: twenty minutes max, then reschedule.",
        "Use written notes if speaking feels too hot.",
        "Celebrate staying regulated; it is skill-building.",
        "Ask partner for softer startup when you're already activated.",
    ]
    for i, parts in enumerate(_take_n(itertools.product(a, b, c), 1000)):
        u = " ".join(p for p in parts if p).strip()
        u = u.replace("  ", " ").strip()
        yield {
            "session_type": st,
            "speaker": sp,
            "emotion": em,
            "conflict_type": cf,
            "response_type": rt,
            "privacy_level": pr,
            "input_text": u,
            "ai_response": responses[i % len(responses)],
        }


def _scenario_listen_rule():
    st, sp, em, cf, rt, pr = (
        "couple",
        "both",
        "calm",
        "argument control",
        "action plan",
        "shared",
    )
    a = [
        "We will listen without interrupting.",
        "We want a no-interruption rule.",
        "We're practicing not cutting each other off.",
        "We agreed to listen fully first.",
        "We're trying one-speaker-at-a-time.",
        "We committed to pausing before jumping in.",
        "We want respectful turn-taking.",
        "We're building a listening pact.",
        "We want to hear each other out fully.",
        "We're done talking over each other.",
    ]
    b = [
        "",
        " Hold us accountable.",
        " Need a simple structure.",
        " What makes this stick?",
        " We want it to last.",
        " We're serious this time.",
        " We need a visible reminder.",
        " We slip when we're tired.",
        " We want kindness plus structure.",
        " We need examples.",
    ]
    c = [
        "",
        " Give us a checklist.",
        " Short steps help.",
        " One page max, please.",
        " We have kids and limited time.",
        " We want to model this for them.",
        " We'll review weekly.",
        " We want encouragement.",
        " We're teammates.",
        " Thank you for guiding us.",
    ]
    responses = [
        "Keep the rule simple: one speaks, one listens, then summarize.",
        "Use a small, clear plan and follow it consistently.",
        "Add a visible timer so turns feel fair.",
        "Summarize before you rebut: did I get you right?",
        "If you slip, apologize fast and restart the turn.",
        "Write the rule on the fridge for week one.",
        "Reward success: end with appreciation.",
        "If emotion spikes, pause the rule and return when calm.",
        "Practice on low-stakes topics first.",
        "Name triggers that make interrupting likely.",
        "Use a gentle hand raise if you need the floor.",
        "Keep phones face down during practice.",
        "Review weekly: what worked, what to tweak?",
        "If stuck, a facilitator can model the rhythm once.",
        "Celebrate patience; listening is a muscle.",
    ]
    for i, parts in enumerate(_take_n(itertools.product(a, b, c), 1000)):
        u = " ".join(p for p in parts if p).strip()
        u = u.replace("  ", " ").strip()
        yield {
            "session_type": st,
            "speaker": sp,
            "emotion": em,
            "conflict_type": cf,
            "response_type": rt,
            "privacy_level": pr,
            "input_text": u,
            "ai_response": responses[i % len(responses)],
        }


def main() -> None:
    out = Path(__file__).resolve().parent / "bridgemend_dataset_10000.csv"
    rows = build_rows()
    if len(rows) != 10000:
        raise SystemExit(f"Expected 10000 rows, got {len(rows)}")

    fieldnames = [
        "session_id",
        "session_type",
        "speaker",
        "input_text",
        "emotion",
        "conflict_type",
        "response_type",
        "privacy_level",
        "ai_response",
        "input_output",
    ]
    with out.open("w", newline="", encoding="utf-8") as f:
        w = csv.DictWriter(f, fieldnames=fieldnames, quoting=csv.QUOTE_MINIMAL)
        w.writeheader()
        for r in rows:
            w.writerow(r)

    print(f"Wrote {len(rows)} rows to {out}")


if __name__ == "__main__":
    main()
