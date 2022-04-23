const PORT = process.env.PORT ?? 3000;
const routes = require("./controller");

function initApp() {
  const app = require("express")();

  Object.values(routes).map(([method, route, handler]) => {
    const _method = method.toLowerCase();
    app[_method](route, handler);
  });

  return app;
}

exports.start = function start() {
  const app = initApp();
  app.listen(PORT, () => {
    console.log(`Server listening on port: ${PORT}`);
  });
};
