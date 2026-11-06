# Task Coach playbook

The practices quizzes are allowed to teach. Every "name the practice" and transfer question
must point at one entry here, and its feedback shows the entry's source. Edit freely: add,
remove or reword entries, and the next quiz uses your version.

Format, so the app can read it: `## Stage`, then one `### id` per practice with **Rule**,
**Why**, **Source** and **Checked** lines.

**How this was checked (November 2026).** Every entry was checked against the page named in its
**Checked** line, by reading that page rather than from memory. Where the original wasn't
reachable (several books, Agans' site, the XP site), a reputable secondary page quoting it was used,
and the entry says so. Wording was tightened wherever the original said less than a draft claimed.
"Common practice" means no single canonical source was found, and is the honest label.

## Scoping the problem

### scope.dig
**Rule:** Check your understanding of the problem with whoever asked, early and again as you learn more.
**Why:** Requirements are learned through feedback, so early assumptions are often wrong.
**Source:** The Pragmatic Programmer (20th anniv. ed.), Tips 77 "Requirements Are Learned in a Feedback Loop" and 78
**Checked:** Adjusted against https://pragprog.com/tips/

### scope.done
**Rule:** Before writing code, write "done" as things a reviewer could check without you there.
**Why:** A piece of work you can't test can't be shown to be finished.
**Source:** INVEST criteria (Bill Wake, 2003), "Testable"
**Checked:** VERIFIED (public part) against https://xp123.com/invest-in-good-stories-and-smart-tasks/

### scope.slices
**Rule:** Split work into small slices that are each useful on their own.
**Why:** Large changes are hard to review, test and integrate safely.
**Source:** INVEST criteria (Bill Wake, 2003), "Small"; DORA, "Working in small batches"
**Checked:** Adjusted against https://dora.dev/capabilities/working-in-small-batches/

### scope.five-whys
**Rule:** Ask why until you reach the real need behind the ticket, before accepting the fix it proposes.
**Why:** Tickets often describe a solution; the real need may call for something smaller or different.
**Source:** Five whys (Taiichi Ohno, Toyota Production System), applied to requirements; primary source not checked
**Checked:** Primary not reachable against https://en.wikipedia.org/wiki/Five_whys

### scope.spike
**Rule:** When a technical question could sink the plan, answer it early with a small spike you throw away.
**Why:** A spike reduces technical risk and makes estimates more reliable, so you don't build on a guess.
**Source:** Extreme Programming, "Create a Spike Solution"; term credited to Kent Beck
**Checked:** Adjusted against https://agiledictionary.com/209/spike/ (via a secondary source; original not reachable)

### scope.non-goals
**Rule:** List non-goals: things that could reasonably be goals but you've chosen to leave out.
**Why:** It keeps scope explicit, so "while we're here" extras don't swell the change.
**Source:** Malte Ubl, "Design Docs at Google"
**Checked:** Public source found against https://www.industrialempathy.com/posts/design-docs-at-google/

## Design and trade-offs

### design.yagni
**Rule:** Don't build a capability now because you presume you'll need it later.
**Why:** Speculative features cost effort to build, delay real work, and add complexity that slows every later change.
**Source:** Martin Fowler, "Yagni" (bliki), from Extreme Programming
**Checked:** Adjusted against https://martinfowler.com/bliki/Yagni.html

### design.easy-change
**Rule:** For a hard change, first make the change easy (this part may be hard), then make the easy change.
**Why:** Forcing a change into code that resists it leaves tangled, fragile results.
**Source:** Kent Beck, "Tidy First?"
**Checked:** Verified against https://newsletter.kentbeck.com/p/tidy-first-example

### design.options
**Rule:** Record each significant decision with its context, the decision, and its consequences, good and bad.
**Why:** Without the reasons, the next person can only blindly accept or blindly reverse it.
**Source:** Michael Nygard, "Documenting Architecture Decisions" (2011)
**Checked:** Adjusted against https://www.cognitect.com/blog/2011/11/15/documenting-architecture-decisions

### design.idempotent
**Rule:** Make operations safe to retry: doing them twice should have the same effect as once.
**Why:** Networks fail mid-request; without this, a retry can create a duplicate, such as a second copy of a resource.
**Source:** AWS Builders' Library, "Making retries safe with idempotent APIs" (Malcolm Featonby)
**Checked:** Adjusted against https://aws.amazon.com/builders-library/making-retries-safe-with-idempotent-APIs/

### design.timeouts
**Rule:** Put a timeout on every remote call, and retry with backoff and jitter.
**Why:** Without timeouts a slow dependency stalls you; instant retries pile on and deepen an outage.
**Source:** AWS Builders' Library, "Timeouts, retries, and backoff with jitter" (Marc Brooker)
**Checked:** Verified against https://aws.amazon.com/builders-library/timeouts-retries-and-backoff-with-jitter/

### design.hyrum
**Rule:** With enough users, assume someone depends on every observable behaviour of your code.
**Why:** Changing "unimportant" behaviour can break callers you didn't know existed.
**Source:** Hyrum's Law; Software Engineering at Google, ch. 1
**Checked:** Adjusted against https://www.hyrumslaw.com/

### design.server-auth
**Rule:** Check permission on the server for every request; never trust the client to enforce it.
**Why:** Access control only works in trusted server-side code; it's the first category in OWASP's 2021 Top 10.
**Source:** OWASP Top 10 (2021), A01 Broken Access Control
**Checked:** Verified against https://owasp.org/Top10/A01_2021-Broken_Access_Control/

### design.least-privilege
**Rule:** Give code, services and people only the access they actually need.
**Why:** Anything with extra access turns a small bug or leak into a large one.
**Source:** Saltzer & Schroeder, "The Protection of Information in Computer Systems" (1975)
**Checked:** Verified against https://web.mit.edu/Saltzer/www/publications/protection/Basic.html

### design.nearest-precedent
**Rule:** Prefer proven approaches you and your team already understand, and justify anything new.
**Why:** Well-known tools and patterns have well-understood failure modes; every new thing carries a long-term cost.
**Source:** Dan McKinley, "Choose Boring Technology"
**Checked:** Public source found (reworded) against https://mcfunley.com/choose-boring-technology

### design.do-less
**Rule:** List real alternatives, including a minimal one that does less, and say why the chosen one wins.
**Why:** Writing down why the chosen option beats the others makes the decision checkable.
**Source:** Malte Ubl, "Design Docs at Google"; Martin Fowler, "Yagni"
**Checked:** Public source found (reworded) against https://www.industrialempathy.com/posts/design-docs-at-google/

### design.failure-modes
**Rule:** Check how each option behaves when it fails, especially rarely used failure paths.
**Why:** Paths that rarely run, like fallbacks, can widen an outage instead of containing it.
**Source:** Amazon Builders' Library, "Avoiding fallback in distributed systems"
**Checked:** Public source found (reworded) against https://aws.amazon.com/builders-library/avoiding-fallback-in-distributed-systems/

### design.srp
**Rule:** Give each module one reason to change: it should answer to one group of people.
**Why:** Code that changes for different reasons should live apart, so a change for one group doesn't break another.
**Source:** Robert C. Martin, "The Single Responsibility Principle" (Clean Code Blog, 2014)
**Checked:** Adjusted against https://blog.cleancoder.com/uncle-bob/2014/05/08/SingleReponsibilityPrinciple.html

### design.ocp
**Rule:** Design modules so new behaviour is added with new code, not by editing code that already works.
**Why:** New features arrive as new code, so working code doesn't have to be changed and redeployed.
**Source:** Bertrand Meyer, Object-Oriented Software Construction (1988); Robert C. Martin, "The Open Closed Principle" (1996, 2014)
**Checked:** Adjusted against https://blog.cleancoder.com/uncle-bob/2014/05/12/TheOpenClosedPrinciple.html

### design.lsp
**Rule:** Code written against a parent type must keep working, with unchanged behaviour, when given any subtype.
**Why:** If a subtype breaks that promise, callers have to check the object's real type.
**Source:** Barbara Liskov, "Data Abstraction and Hierarchy" (1987); Liskov & Wing, "A Behavioral Notion of Subtyping" (1994); popularised by Robert C. Martin (1996)
**Checked:** Adjusted against https://cs.utexas.edu/~downing/papers/LSP-1996.pdf (via a university copy of Martin's column)

### design.isp
**Rule:** Don't make callers depend on methods they don't use; split wide interfaces into focused ones.
**Why:** A caller that depends on methods it doesn't use is still affected when those methods change for other callers.
**Source:** Robert C. Martin, "The Interface Segregation Principle" (The C++ Report, 1996)
**Checked:** Adjusted against https://cs.utexas.edu/~downing/papers/ISP-1996.pdf (via a university copy of the column)

### design.dip
**Rule:** High-level rules shouldn't depend on low-level details; both should depend on abstractions that the details implement.
**Why:** Business rules tied to details like a specific database can't be reused or changed independently of them.
**Source:** Robert C. Martin, "The Dependency Inversion Principle" (The C++ Report, 1996)
**Checked:** Adjusted against https://blog.cleancoder.com/uncle-bob/2020/10/18/Solid-Relevance.html

## System design

### sys.stateless
**Rule:** Keep service instances stateless and put state in a backing store.
**Why:** Instances can then be added, removed or restarted without losing data.
**Source:** The Twelve-Factor App, VI "Processes"
**Checked:** Verified against https://12factor.net/processes

### sys.cap
**Rule:** During a network partition each operation must either stay consistent (and may refuse) or stay available (and may be stale); without a partition you can have both.
**Why:** Partitions are rare but can't be ruled out, so plan for that moment instead of assuming you'll get both.
**Source:** Eric Brewer, CAP conjecture (2000); Gilbert & Lynch, proof (2002); Brewer, "CAP Twelve Years Later" (IEEE Computer, 2012)
**Checked:** Adjusted (coordinator checked brewer 2012) against https://www.infoq.com/articles/cap-twelve-years-later-how-the-rules-have-changed

### sys.fallacies
**Rule:** Don't assume the network is reliable, fast, secure or unchanging; these are among the eight fallacies of distributed computing.
**Why:** Code written as if remote calls always succeed quickly fails in production.
**Source:** The Fallacies of Distributed Computing (L. Peter Deutsch and colleagues at Sun, 1994; eighth added by James Gosling)
**Checked:** Adjusted against https://en.wikipedia.org/wiki/Fallacies_of_distributed_computing (via a secondary source; original not reachable)

### sys.cache-staleness
**Rule:** Before adding a cache, decide how stale each caller can tolerate, set expiry from that, and plan for an empty or lost cache.
**Why:** Cached data drifts from its source, and a cache that quietly becomes critical can overload the backend when it's cold.
**Source:** "Caching challenges and strategies" (Amazon Builders' Library, 2019)
**Checked:** Adjusted against https://aws.amazon.com/builders-library/caching-challenges-and-strategies/

### sys.circuit-breaker
**Rule:** After repeated failures, stop calling a dependency for a cooling-off period, then let a trial call through.
**Why:** Repeated calls to a failing service waste resources and can spread the failure.
**Source:** Martin Fowler, "Circuit Breaker"; popularised by Michael Nygard, Release It!
**Checked:** Verified against https://martinfowler.com/bliki/CircuitBreaker.html

### sys.bulkhead
**Rule:** Give each dependency its own pool of resources, so one slow dependency can't use them all.
**Why:** Without isolation, one slow dependency can exhaust shared threads or connections and take everything down.
**Source:** Microsoft Azure Architecture Center, "Bulkhead pattern"
**Checked:** Verified against https://learn.microsoft.com/en-us/azure/architecture/patterns/bulkhead

### sys.queue-levelling
**Rule:** Put a queue between bursty producers and the service that processes them, and keep consumers able to keep up on average.
**Why:** The queue absorbs spikes; but if work arrives faster than it's processed on average, the queue just grows.
**Source:** Microsoft Azure Architecture Center, "Queue-Based Load Leveling pattern"
**Checked:** Adjusted against https://learn.microsoft.com/en-us/azure/architecture/patterns/queue-based-load-leveling

### sys.idempotent-consumer
**Rule:** Assume a message can arrive more than once; record processed message IDs and skip duplicates.
**Why:** Most message brokers deliver at least once, so duplicates will happen.
**Source:** Chris Richardson, microservices.io, "Idempotent Consumer"
**Checked:** Verified against https://microservices.io/patterns/communication-style/idempotent-consumer.html

### sys.outbox
**Rule:** Save a database change and the event announcing it in the same transaction, then publish from there.
**Why:** Writing to the database and the broker separately can leave them out of step; the relay may publish twice, so pair it with idempotent consumers.
**Source:** Chris Richardson, microservices.io, "Transactional outbox"
**Checked:** Verified against https://microservices.io/patterns/data/transactional-outbox.html

### sys.throttle
**Rule:** Cap how much load each caller or tenant can put on a service, and reject the excess with a clear retry signal.
**Why:** Without limits, one tenant or client can monopolise capacity and degrade the service for everyone.
**Source:** Microsoft Azure Architecture Center, "Throttling pattern"
**Checked:** Adjusted against https://learn.microsoft.com/en-us/azure/architecture/patterns/throttling

### sys.degrade
**Rule:** Decide in advance how the system sheds work or serves cheaper results under overload, and exercise that path regularly.
**Why:** Planned degradation keeps essential features working; unplanned overload tends to cascade, and untested degradation code breaks.
**Source:** Site Reliability Engineering (Google), ch. 22 "Addressing Cascading Failures"
**Checked:** Adjusted against https://sre.google/sre-book/addressing-cascading-failures/

### sys.replica-lag
**Rule:** Expect read replicas to lag; for data a user has just changed, read from the primary.
**Why:** Otherwise users can make a change and then not see it; reading everything from the primary doesn't scale.
**Source:** Martin Kleppmann, Designing Data-Intensive Applications, ch. 5, "Reading your own writes"
**Checked:** Book not reachable against https://dev.to/mhkarami97/the-ghost-post-when-users-cant-see-their-own-writes-1kba (via a secondary source; the book wasn't reachable)

### sys.indexes
**Rule:** Index the columns your queries filter and join on, mind column order, and check the plan to confirm the index is used.
**Why:** Without a suitable index the database reads far more rows than it returns; indexes also cost write time, so add them for real queries.
**Source:** Markus Winand, Use The Index, Luke
**Checked:** Adjusted against https://use-the-index-luke.com/sql/anatomy

### sys.estimate
**Rule:** Do a rough estimate of load, data size and latency before choosing a design.
**Why:** A quick calculation with rough latency numbers rules out designs that can't cope; use orders of magnitude, as exact figures date.
**Source:** Jeff Dean, "Building Software Systems at Google and Lessons Learned" (Stanford, 2010), "Numbers Everyone Should Know"
**Checked:** Adjusted against https://web.stanford.edu/class/ee380/Abstracts/101110-slides.pdf

## Reading code

### reading.for-reader
**Rule:** Write code for the next reader, not for yourself today.
**Why:** Code lives a long time, so far more time goes on reading it than writing it.
**Source:** Google C++ Style Guide, "Optimize for the reader, not the writer"
**Checked:** ADJUSTED (checker wrong; coordinator verified) against https://google.github.io/styleguide/cppguide.html

### reading.fence
**Rule:** Find out why existing code is there before you remove or change it.
**Why:** Odd-looking code often guards a case you haven't hit yet.
**Source:** Chesterton's fence (G. K. Chesterton, The Thing, 1929)
**Checked:** Verified against https://www.lesswrong.com/w/chesterton-s-fence (via a secondary source; original not reachable)

### reading.trace-paths
**Rule:** Trace every path that already flows through a spot before adding a guard there.
**Why:** A new check can block cases that were already handled correctly further on.
**Source:** Common practice
**Checked:** No single named source found; honest label is common practice

### reading.end-to-end
**Rule:** Follow one real request end to end before changing anything along its path.
**Why:** Changing the middle of a flow without knowing its inputs and readers causes surprise breakages.
**Source:** Common practice
**Checked:** No single named source found; honest label is common practice

### reading.characterise
**Rule:** Before changing legacy code, pin down what it actually does today with characterisation tests.
**Why:** You can't tell whether you broke something if you never captured what it did.
**Source:** Michael Feathers, Working Effectively with Legacy Code, ch. 13
**Checked:** Verified against https://alvarogarcia7.github.io/blog/2016/04/18/quote-characterization-tests/ (via a secondary source; original not reachable)

### reading.check-dont-recall
**Rule:** Look up the real signature, config key or field name instead of typing it from memory.
**Why:** Assumptions should be proven in the real environment; remembered names look right and fail at runtime.
**Source:** The Pragmatic Programmer, Tip 34 "Don't Assume It, Prove It"
**Checked:** Public source found against https://pragprog.com/tips/

## Testing

### test.pyramid
**Rule:** Write many fast unit tests, fewer integration tests, and very few end-to-end tests.
**Why:** Broad, slow tests are flaky and costly; most bugs are cheaper to catch lower down.
**Source:** Martin Fowler, "TestPyramid" (bliki); popularised by Mike Cohn, Succeeding with Agile
**Checked:** Adjusted against https://martinfowler.com/bliki/TestPyramid.html

### test.see-fail
**Rule:** Watch a new test fail for the right reason before you trust it passing.
**Why:** It rules out a broken test that would always pass.
**Source:** Test-driven development (Kent Beck, Test-Driven Development by Example)
**Checked:** Verified against https://en.wikipedia.org/wiki/Test-driven_development (via a secondary source; original not reachable)

### test.beyonce
**Rule:** If you want a behaviour kept, put a test on it.
**Why:** Anything without a test is fair game for the next change to break, and the break is on whoever skipped the test.
**Source:** Software Engineering at Google, ch. 11 "Testing Overview", the Beyoncé Rule
**Checked:** Verified against https://abseil.io/resources/swe-book/html/ch11.html

### test.behaviour
**Rule:** Test what the code does through its public interface, not how it does it inside.
**Why:** Tests tied to internals break on every refactor and stop being trusted.
**Source:** Software Engineering at Google, ch. 12 "Unit Testing": "Test via public APIs", "Test behaviors, not methods"
**Checked:** Verified against https://abseil.io/resources/swe-book/html/ch12.html

### test.edges
**Rule:** Test the edges: empty, one, many, the boundary values, and the failure paths.
**Why:** Boundaries are a common place for errors, and happy-path tests skip them.
**Source:** Boundary value analysis (ISTQB black-box technique)
**Checked:** Adjusted against https://en.wikipedia.org/wiki/Boundary-value_analysis

### test.repro-first
**Rule:** When fixing a bug, first write a test that reproduces it.
**Why:** It proves you understood the bug, and stops it coming back.
**Source:** The Pragmatic Programmer (20th anniv. ed.), Tip 31 "Failing Test Before Fixing Code"
**Checked:** Re-sourced against https://pragprog.com/tips/

### test.flaky
**Rule:** Treat flaky tests as a cost to remove, not background noise.
**Why:** Every flake needs investigating, and as flakiness grows people lose confidence in the whole suite.
**Source:** Software Engineering at Google, ch. 11 "Testing Overview"
**Checked:** Adjusted against https://abseil.io/resources/swe-book/html/ch11.html

### test.fear-first
**Rule:** Write tests until you're no longer worried about the change, starting with the risk that worries you most.
**Why:** Tests turn worry about a change into confidence you can check.
**Source:** Kent Beck, Test-Driven Development: By Example
**Checked:** Public source found (reworded) against https://www.goodreads.com/work/quotes/376827 (via a quote page; the book wasn't reachable)

## Code review

### review.code-health
**Rule:** Approve once a change clearly improves code health, even if it isn't perfect.
**Why:** There's no such thing as perfect code; holding out for it stalls changes that already help.
**Source:** Google Engineering Practices, "The Standard of Code Review"
**Checked:** Verified against https://google.github.io/eng-practices/review/reviewer/standard.html

### review.small
**Rule:** Keep each change small and about one thing.
**Why:** Small changes get faster, more thorough reviews and are easier to roll back.
**Source:** Google Engineering Practices, "Small CLs"
**Checked:** Verified against https://google.github.io/eng-practices/review/developer/small-cls.html

### review.description
**Rule:** Describe what changed and why, not just which files moved.
**Why:** Reviewers and future readers need the reason, which the diff can't show.
**Source:** Google Engineering Practices, "Writing good CL descriptions"
**Checked:** Verified against https://google.github.io/eng-practices/review/developer/cl-descriptions.html

### review.design-first
**Rule:** Review the overall design first, and send design problems straight away.
**Why:** If the design is wrong, much of the code may be thrown away, and the author may already be building on it.
**Source:** Google Engineering Practices, "What to look for in a code review" and "Navigating a CL in review"
**Checked:** Adjusted against https://google.github.io/eng-practices/review/reviewer/navigate.html

### review.comments
**Rule:** Comment on the code, never the person, explain why, and mark minor points as Nit, Optional or FYI.
**Why:** Courteous, explained comments are easier to act on, and labels show the author what is required.
**Source:** Google Engineering Practices, "How to write code review comments"
**Checked:** Adjusted against https://google.github.io/eng-practices/review/reviewer/comments.html

### review.injection
**Rule:** Never build queries or commands by gluing user input into a string.
**Why:** It lets an attacker run their own query or command through yours.
**Source:** OWASP Top 10 (2021), A03 Injection
**Checked:** Verified against https://owasp.org/Top10/A03_2021-Injection/

### review.whats-missing
**Rule:** Read around the diff, not just the changed lines, and check that tests, error paths, callers and clean-up are covered.
**Why:** What's missing doesn't show up in a diff, so you have to go looking for it.
**Source:** Google Engineering Practices, "What to look for in a code review"
**Checked:** Public source found (reworded) against https://google.github.io/eng-practices/review/reviewer/looking-for.html

### review.follow-risk
**Rule:** Read every line you're asked to review, and give extra scrutiny to security, money and data isolation.
**Why:** Some code deserves more careful scrutiny than other code.
**Source:** Google Engineering Practices, "What to look for in a code review"
**Checked:** Public source found (reworded) against https://google.github.io/eng-practices/review/reviewer/looking-for.html

### review.label-findings
**Rule:** Label each review comment by severity, separating required changes from suggestions.
**Why:** The author can see at once what must change and what is optional.
**Source:** Google Engineering Practices, "How to write code review comments"
**Checked:** Public source found against https://google.github.io/eng-practices/review/reviewer/comments.html

### review.state-coverage
**Rule:** You own what you approve, so say what you checked and what you didn't.
**Why:** A bare approval implies you vouch for everything.
**Source:** Google Engineering Practices, "The Standard of Code Review" (reviewer ownership)
**Checked:** Public source found (narrowed) against https://google.github.io/eng-practices/review/reviewer/standard.html

## Shipping safely

### ship.small-batches
**Rule:** Ship small changes often rather than big changes rarely.
**Why:** Small batches are easier to test and verify, get feedback sooner, and make problems easier to fix.
**Source:** DORA, "Working in small batches"
**Checked:** Adjusted against https://dora.dev/capabilities/working-in-small-batches/

### ship.expand-contract
**Rule:** Change schemas and APIs in steps: add the new, move over, then remove the old.
**Why:** One-step changes break whatever is still running the old version mid-deploy.
**Source:** Danilo Sato, "ParallelChange" (martinfowler.com bliki)
**Checked:** Verified against https://martinfowler.com/bliki/ParallelChange.html

### ship.flags
**Rule:** Use feature flags to separate deploying from releasing, and remove them once released.
**Why:** Flags let you switch things off fast, but stale ones pile up as hidden complexity.
**Source:** Pete Hodgson, "Feature Toggles" (martinfowler.com)
**Checked:** Verified against https://martinfowler.com/articles/feature-toggles.html

### ship.canary
**Rule:** Roll out to a small slice first and watch the metrics before going to everyone.
**Why:** A defect in a small slice of traffic hurts few users, so it's far cheaper to find than at full rollout.
**Source:** The Site Reliability Workbook (Google), "Canarying Releases"
**Checked:** Adjusted against https://sre.google/workbook/canarying-releases/

### ship.rollback
**Rule:** Before shipping, know how you'll safely undo the change, and make that path quick.
**Why:** Safe rollback is a core part of change management; a release that's hard to reverse turns a bad change into an incident.
**Source:** Site Reliability Engineering (Google), "Introduction" (change management); Workbook, "Canarying Releases"
**Checked:** Re-sourced against https://sre.google/sre-book/introduction/

### ship.blast-radius
**Rule:** Ask who and what else a change can affect before you ship it.
**Why:** Unknown dependants are where "small" changes cause big incidents.
**Source:** Common practice
**Checked:** No single named source found; honest label is common practice

### ship.self-review
**Rule:** Review your own diff before asking for review, and keep it to one purpose: no debug prints, dead code or drive-by edits.
**Why:** A focused, self-checked change is faster and safer to review.
**Source:** Google Engineering Practices, "Small CLs" and "Writing good CL descriptions"
**Checked:** Public source found (reworded) against https://google.github.io/eng-practices/review/developer/small-cls.html

### ship.refactor-apart
**Rule:** Do refactoring in a separate change from feature work or bug fixes; tiny local clean-ups excepted.
**Why:** Reviewers can't tell an intended behaviour change from an accidental one, so regressions slip through.
**Source:** Google Engineering Practices, "Small CLs"
**Checked:** Public source found against https://google.github.io/eng-practices/review/developer/small-cls.html

### ship.migrate-slices
**Rule:** Replace an old way incrementally, in slices that each ship, then retire the old path and any temporary flags.
**Why:** Gradual replacement is far less risky than a big-bang rewrite.
**Source:** Martin Fowler, "Strangler Fig Application"; "Feature Toggle"
**Checked:** Public source found (reworded) against https://martinfowler.com/bliki/StranglerFigApplication.html

## Operating and incidents

### ops.golden-signals
**Rule:** Watch latency, traffic, errors and saturation for every service.
**Why:** If you can only measure four things about a user-facing system, these give decent coverage.
**Source:** Site Reliability Engineering (Google), "Monitoring Distributed Systems"
**Checked:** Adjusted against https://sre.google/sre-book/monitoring-distributed-systems/

### ops.symptoms
**Rule:** Page on urgent, user-visible symptoms; keep cause-based signals as debugging aids.
**Why:** Too many pages make people skim or ignore alerts, which can make outages longer.
**Source:** Site Reliability Engineering (Google), "Monitoring Distributed Systems"
**Checked:** Adjusted against https://sre.google/sre-book/monitoring-distributed-systems/

### ops.mitigate-first
**Rule:** In an incident, stop the bleeding and restore service first, keeping evidence for the root cause.
**Why:** The first goal is getting users working again; the evidence lets you find the cause once they are.
**Source:** Site Reliability Engineering (Google), "Managing Incidents"
**Checked:** Adjusted against https://sre.google/sre-book/managing-incidents/

### ops.blameless
**Rule:** Write blameless postmortems that fix systems, not people.
**Why:** Blame makes people hide mistakes, so the same failure happens again.
**Source:** Site Reliability Engineering (Google), "Postmortem Culture: Learning from Failure"
**Checked:** Verified against https://sre.google/sre-book/postmortem-culture/

### ops.correlate
**Rule:** Log with correlation IDs so one request can be traced as it passes through the system.
**Why:** Logs without correlation IDs can't answer "what happened to this request?".
**Source:** Microsoft Azure Architecture Center, "Monitoring and diagnostics" best practices
**Checked:** Re-sourced against https://learn.microsoft.com/en-us/azure/architecture/best-practices/monitoring

### ops.keep-evidence
**Rule:** While restoring service, preserve logs, affected IDs, timestamps and dumps before a rollback or restart wipes them.
**Why:** Restoring service often destroys the only evidence, and the investigation becomes guesswork.
**Source:** Site Reliability Engineering (Google), "Managing Incidents"; PagerDuty Incident Response
**Checked:** Public source found against https://sre.google/sre-book/managing-incidents/

### ops.cadence
**Rule:** During an incident, post regular updates on a set rhythm: impact, current action, and when the next update is.
**Why:** Silence reads as nobody being on it, and people interrupt you instead.
**Source:** The Site Reliability Workbook (Google), "Incident Response"; PagerDuty Incident Response
**Checked:** Public source found against https://sre.google/workbook/incident-response/

## Debugging and root cause

### debug.understand
**Rule:** Understand how the system should work before you try to fix it.
**Why:** The parts you don't understand are often where the bug is.
**Source:** David Agans, Debugging: The 9 Indispensable Rules, rule 1 "Understand the system"
**Checked:** Verified against https://embeddedartistry.com/blog/2017/9/6/debugging-9-indispensable-rules (via a secondary source; original not reachable)

### debug.make-it-fail
**Rule:** Make it fail reliably before you try to fix it.
**Why:** You can't confirm a fix for a bug you can't reproduce.
**Source:** Agans, rule 2 "Make it fail"
**Checked:** Verified against https://embeddedartistry.com/blog/2017/9/6/debugging-9-indispensable-rules (via a secondary source; original not reachable)

### debug.look
**Rule:** Watch the actual failure with logs, data or a debugger; use guesses only to decide where to look.
**Why:** A theory feels like progress, but it's only a guess until you've seen the failure.
**Source:** Agans, rule 3 "Quit thinking and look"
**Checked:** Adjusted against https://embeddedartistry.com/blog/2017/9/6/debugging-9-indispensable-rules (via a secondary source; original not reachable)

### debug.divide
**Rule:** Narrow down where the fault is by halving the search space each step.
**Why:** Halving finds the fault in a handful of steps; wandering can take all day.
**Source:** Agans, rule 4 "Divide and conquer"
**Checked:** Verified against https://embeddedartistry.com/blog/2017/9/6/debugging-9-indispensable-rules (via a secondary source; original not reachable)

### debug.one-change
**Rule:** Change one thing at a time.
**Why:** Change two things and you won't know which one mattered.
**Source:** Agans, rule 5 "Change one thing at a time"
**Checked:** Verified against https://embeddedartistry.com/blog/2017/9/6/debugging-9-indispensable-rules (via a secondary source; original not reachable)

### debug.check-plug
**Rule:** Check the obvious first: config, versions, environment, whether it's even running.
**Why:** A surprising number of "deep" bugs are a wrong setting or a stale deploy.
**Source:** Agans, rule 7 "Check the plug"
**Checked:** Verified against https://embeddedartistry.com/blog/2017/9/6/debugging-9-indispensable-rules (via a secondary source; original not reachable)

### debug.really-fixed
**Rule:** Prove the fix: take it out and see the failure return, put it back and see it stop.
**Why:** Without that proof you may have only hidden the symptom, and the bug will come back.
**Source:** Agans, rule 9 "If you didn't fix it, it ain't fixed"
**Checked:** Adjusted against https://embeddedartistry.com/blog/2017/9/6/debugging-9-indispensable-rules (via a secondary source; original not reachable)

### debug.mechanism
**Rule:** Outside an active incident, don't call a bug fixed until you can state its mechanism and have verified the fix.
**Why:** An unverified fix may just be an intermittent bug gone quiet; during an incident, mitigate first and explain after.
**Source:** Site Reliability Engineering (Google), "Effective Troubleshooting"; Agans, rule 9
**Checked:** Public source found (reworded) against https://sre.google/sre-book/effective-troubleshooting/

### debug.what-changed
**Rule:** Start with what changed (deploys, config, flags, data, dependencies, load) before reading code open-endedly.
**Why:** Recent changes are a productive place to start looking.
**Source:** Site Reliability Engineering (Google), "Effective Troubleshooting"
**Checked:** Public source found against https://sre.google/sre-book/effective-troubleshooting/

### debug.write-hypotheses
**Rule:** Write down each hypothesis and what you tested as you go.
**Why:** A working record keeps you honest and stops you repeating experiments.
**Source:** Site Reliability Engineering (Google), "Effective Troubleshooting"; Agans, rule 6 "Keep an audit trail"
**Checked:** Public source found (reworded) against https://sre.google/sre-book/effective-troubleshooting/

### debug.why-now
**Rule:** A root cause should explain the trigger, such as a change or a new kind of load, as well as the defect.
**Why:** A cause deep enough to explain the trigger tells you where the bug could come back.
**Source:** Site Reliability Engineering (Google), "Effective Troubleshooting" and "Postmortem Culture"
**Checked:** Public source found (reworded) against https://sre.google/sre-book/effective-troubleshooting/

## Explaining your work

### explain.bluf
**Rule:** Lead with the conclusion, then give the reasons.
**Why:** A busy reader can decide sooner, and a skimmer can't miss the point.
**Source:** BLUF (bottom line up front); Barbara Minto, The Pyramid Principle (1985)
**Checked:** Adjusted against https://en.wikipedia.org/wiki/Bottom_line_up_front

### explain.cause-fix-proof
**Rule:** For a bug, say the cause, the fix, and how you checked it.
**Why:** That's what a lead needs to trust the change without re-reading it.
**Source:** Common practice
**Checked:** No single named source found; honest label is common practice

### explain.unknowns
**Rule:** Say clearly what you haven't verified or don't know.
**Why:** Hidden uncertainty turns into someone else's surprise later.
**Source:** Common practice
**Checked:** No single named source found; honest label is common practice

### explain.audience
**Rule:** Pitch it to what the reader needs to decide or do.
**Why:** Detail that doesn't serve the reader buries the part they need.
**Source:** Common practice
**Checked:** No single named source found; honest label is common practice

### explain.verified
**Rule:** Don't report a fix as done until you've verified it, and say what you haven't verified.
**Why:** If you didn't fix it, it ain't fixed, and an unchecked "done" spreads that mistake.
**Source:** Agans, rule 9 "If you didn't fix it, it ain't fixed"
**Checked:** Public source found (narrowed) against https://embeddedartistry.com/blog/2017/9/6/debugging-9-indispensable-rules (via a secondary source; original not reachable)
