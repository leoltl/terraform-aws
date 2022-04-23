function index(req, res) {
  res.send("Hello World");
}

module.exports = { index: ["GET", "/", index] };
