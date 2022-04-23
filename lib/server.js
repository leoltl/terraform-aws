const PORT = process.env.PORT ?? 3000;

function initApp() {
  const app = require("express")();

  app.get("/", (_, res) => {
    res.send("hello world");
  });

  return app;
}

exports.start = function start() {
  const app = initApp();
  app.listen(PORT, () => {
    console.log(`Server listening on port: ${PORT}`);
  });
};
