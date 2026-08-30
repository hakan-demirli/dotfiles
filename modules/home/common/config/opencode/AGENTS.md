# Language

- Use ASD-STE100 Simplified Technical English

# Authentication and Authorization

- Do NOT open remote MRs, PRs or issues unless EXPLICITLY asked for.
- Do NOT create comments, answers, discussions or reviews on remote repos or PRs unless EXPLICITLY asked for.
- Ambiguous remote action request (e.g. PR, comment, ...) stop and ask. Do NOT guess.
- Do NOT use accounts, tokens, and keys without EXPLICIT permission, those represent the user.

# Development Standards

- Follow the existing repo/code style. Do NOT add comments if repo does not have. Do NOT create arbitrary dirs.
- No hacks or bandaids unless EXPLICILY asked for.
- Always design for long term professional quality software architecture.
- Always follow best practices for performance, scalability and readability.
- Prefer build time failures over runtime failures.
- If applicable to the repo style, parse, don't validate. Transform raw, untyped data into structured, strongly-typed representations at the application boundaries rather than scattering validation checks throughout the codebase (avoid "shotgun parsing").
- If applicable to the repo style, make illegal states unrepresentable. Leverage the type system (using enums, newtypes, and custom data structures) to guarantee that invalid or nonsensical data simply cannot exist in the program's state.
- If applicable to the repo style, Strengthen function parameters instead of weakening return types. Push validation responsibility to the caller by requiring specialized types (e.g., NonEmptyVec) as inputs to prove invariants upfront, rather than taking generic types and returning an Option or Result.
- If applicable to the repo style, use semantic types over primitives. Avoid primitive obsession and "boolean blindness" (e.g., using a generic bool or i32 for domain concepts). Define descriptive enums or newtypes to clearly communicate intent and enforce correctness at compile time.
- Follow the existing repo/code style.
- FOLLOW the existing repo/code style!
