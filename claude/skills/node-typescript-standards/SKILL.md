---
name: node-typescript-standards
description: Personal Node and TypeScript toolchain and conventions. Apply whenever working in Node.js, TypeScript, or JavaScript — writing, editing, linting, formatting, type-checking, or testing. Triggers on .ts/.tsx/.js/.mjs files, package.json, tsconfig.json, pnpm/npm usage, or any task involving Node/TS dependencies, ESM modules, or supply chain. Use this automatically when the work is clearly Node or TypeScript, even if the user doesn't name a specific tool.
---

# Node / TypeScript Standards

**Runtime:** Node 22 LTS, ESM only (`"type": "module"`)

| purpose | tool |
|---------|------|
| lint | `oxlint` |
| format | `oxfmt` |
| test | `vitest` |
| types | `tsc --noEmit` |

**Always use oxlint and oxfmt** over eslint/prettier — they're faster and stricter. Enable `typescript`, `import`, `unicorn` plugins.

## tsconfig.json strictness — enable all of these

```jsonc
"strict": true,
"noUncheckedIndexedAccess": true,
"exactOptionalPropertyTypes": true,
"noImplicitOverride": true,
"noPropertyAccessFromIndexSignature": true,
"verbatimModuleSyntax": true,
"isolatedModules": true
```

Colocated `*.test.ts` files.

## Supply chain
- `pnpm audit --audit-level=moderate` before installing
- Pin exact versions (no `^` or `~`)
- Enforce 24-hour publish delay: `pnpm config set minimumReleaseAge 1440`
- Block postinstall scripts: `pnpm config set ignore-scripts true`
