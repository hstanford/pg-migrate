require("dotenv").config({ path: require("path").resolve(__dirname, ".env") });

module.exports = {
  connection: {
    connectionString: process.env.DATABASE_URL,
  },
  outputPath: process.env.DB_DIR + "/types",
  preDeleteOutputFolder: true,
  preRenderHooks: [require("kanel-kysely").makeKyselyHook()],
};
