const sinon = require("sinon");
const assert = require("assert");
const { index } = require("../lib/controller");
const { getHanderFromRouteConfig } = require("./utils");

describe("#controllers", () => {
  const sandbox = sinon.createSandbox();

  afterEach(() => {
    sandbox.restore();
  });

  describe("#index", () => {
    it("should call .send", async () => {
      // arrange
      const handler = getHanderFromRouteConfig(index);
      const mockSend = sandbox.spy();

      // assert
      await handler({}, { send: mockSend });

      // assert
      assert(mockSend.called);
    });

    it("should send back 'Hello World'", async () => {
      // arrange
      const handler = getHanderFromRouteConfig(index);
      const mockSend = sandbox.spy();

      // assert
      await handler({}, { send: mockSend });

      // assert
      assert(mockSend.calledWith("Hello World !"));
    });
  });
});
