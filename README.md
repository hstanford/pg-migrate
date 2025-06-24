# @stanstack/pg-migrate

A simple, scriptable PostgreSQL migration and schema management toolkit for Node.js/TypeScript projects. This package provides CLI tools to initialize your database directory, manage migrations, and generate type-safe database code using [apgdiff](https://github.com/lovelysystems/apgdiff), [pgvector](https://github.com/pgvector/pgvector), [Kysely](https://kysely.dev) and [Kanel](https://github.com/kristiandupont/kanel).

---

## Concept

The `schema.sql` file is the canonical source of truth for your database schema. You cannot tear down your production database and create it again every time you make a change to the schema. Instead, `pg-migrate` works out the diff between the `schema.sql` file and the current state of your database, and saves that diff as a migration file in the `migrations` directory (which can be edited manually if needed). The migrations are then applied to your database.

This way you get both control over what's getting applied to your production database, and the speed and clarity of the thing that you're editing being the source of truth - just like any other code.

---

## Why these technologies?

### apgdiff

[apgdiff](https://github.com/lovelysystems/apgdiff) is a currently (as of 2025-06-24) maintained diff tool that is easy to use via docker. It's got broad support for PostgreSQL features.

### pgvector

[pgvector](https://github.com/pgvector/pgvector) is the vector database extension for PostgreSQL. A lot of modern applications have needs for vector data, and pgvector is a good choice for that.

### Kysely

[Kysely](https://kysely.dev) is a SQL query builder for TypeScript/JavaScript. It is a good choice for database access in a Node.js/TypeScript project: giving you the full power of SQL while maintaining type safety.

### Kanel

[Kanel](https://github.com/kristiandupont/kanel) is a SQL to TypeScript generator that integrates well with Kysely.

---

## Getting Started

### 1. Install the Package

Add `@stanstack/pg-migrate` to your project:

```sh
npm install --save-dev @stanstack/pg-migrate
```

or with your preferred package manager:

```sh
pnpm add -D @stanstack/pg-migrate
```

### 2. Initialize Your Database Directory

Run the `init` script to set up your database directory. You can specify a custom path or accept the default (`./db`).

```sh
npx @stanstack/pg-migrate init
# or, with a custom directory
npx @stanstack/pg-migrate init ./my-db-dir
```

This will create the specified directory (if it doesn't exist) with all the necessary files and directories for your database.

### 3. Configure Environment Variables

Use the following environment variables for any commands you run:

```
DATABASE_URL=postgres://user:password@host:port/database
DB_DIR=./db  # Or your chosen database directory
```

### 4. Make a Change

Edit `schema.sql` to make your desired changes to the schema.

### 5. Generate a Migration

Run the `generate` script to generate a migration file based on the diff between `schema.sql` and your current database state:

```sh
npx @stanstack/pg-migrate generate "description"
```

### 6. \[Optional\] Edit the Migration

If you need to make changes to the generated migration, you can edit the file in the `migrations` directory.

### 7. Apply the Migration

Run the `migrate` script to apply the migration to your database:

```sh
npx @stanstack/pg-migrate migrate
```

### 8. Develop your Application

Use the types generated in `types` with Kysely to develop your application with type safety. Repeat steps 4-7 as you develop the application.

---

## Freebies

A `docker-compose.yml` file is provided for convenience. It sets up a PostgreSQL database with the necessary environment variables.

---

## Requirements

- Node.js 18+
- Docker (this is required for diffing the schema)

---

## License

MIT
