import { describe, it, expect } from "vitest";
import { AccessControl } from "../../src/brain/access-control.js";

describe("AccessControl", () => {
  describe("open mode", () => {
    it("allows everyone", () => {
      const ac = new AccessControl("open");
      expect(ac.check("anyone")).toBe("allowed");
    });
  });

  describe("private mode", () => {
    it("allows owner", () => {
      const ac = new AccessControl("private");
      ac.setOwner("owner:1");
      expect(ac.check("owner:1")).toBe("allowed");
    });

    it("denies non-owner", () => {
      const ac = new AccessControl("private");
      ac.setOwner("owner:1");
      expect(ac.check("stranger:2")).toBe("denied");
    });

    it("allows when no owner set", () => {
      const ac = new AccessControl("private");
      expect(ac.check("anyone")).toBe("allowed");
    });
  });

  describe("approval mode", () => {
    it("returns pending for unknown user", () => {
      const ac = new AccessControl("approval");
      ac.setOwner("owner:1");
      expect(ac.check("stranger:2")).toBe("pending");
    });

    it("allows approved user", () => {
      const ac = new AccessControl("approval");
      ac.setOwner("owner:1");
      ac.approve("friend:2");
      expect(ac.check("friend:2")).toBe("allowed");
    });

    it("always allows owner", () => {
      const ac = new AccessControl("approval");
      ac.setOwner("owner:1");
      expect(ac.check("owner:1")).toBe("allowed");
    });
  });

  it("can change mode", () => {
    const ac = new AccessControl("open");
    expect(ac.getMode()).toBe("open");
    ac.setMode("private");
    expect(ac.getMode()).toBe("private");
  });
});
