import unittest

from select_simulator import choose, creatable

DEVICES = {
    "com.apple.CoreSimulator.SimRuntime.iOS-26-2": [
        {"name": "iPhone 17 Pro", "udid": "old-phone", "isAvailable": True},
    ],
    "com.apple.CoreSimulator.SimRuntime.iOS-27-1": [
        {"name": "iPhone Air", "udid": "air", "isAvailable": True},
        {"name": "iPhone 17 Pro", "udid": "pro", "isAvailable": True},
        {"name": "iPhone Duo", "udid": "duo", "isAvailable": True},
        {"name": "iPad Pro 11-inch (M5)", "udid": "ipad", "isAvailable": True},
    ],
}


class SelectSimulatorTests(unittest.TestCase):
    def test_prefers_named_device_on_newest_supported_runtime(self):
        self.assertEqual(choose(DEVICES, "iphone", (27, 1, 0)), "pro")
        self.assertEqual(choose(DEVICES, "ipad", (27, 1, 0)), "ipad")
        self.assertEqual(choose(DEVICES, "duo", (27, 1, 0)), "duo")

    def test_iphone_family_never_picks_the_duo(self):
        devices = {"com.apple.CoreSimulator.SimRuntime.iOS-27-1": [
            {"name": "iPhone Duo", "udid": "duo", "isAvailable": True},
            {"name": "iPhone 18", "udid": "phone", "isAvailable": True},
        ]}
        self.assertEqual(choose(devices, "iphone", (27, 1, 0)), "phone")

    def test_runtimes_below_minimum_and_unavailable_devices_are_ignored(self):
        self.assertIsNone(choose({"com.apple.CoreSimulator.SimRuntime.iOS-26-2": DEVICES[
            "com.apple.CoreSimulator.SimRuntime.iOS-26-2"]}, "iphone", (27, 1, 0)))
        devices = {"com.apple.CoreSimulator.SimRuntime.iOS-27-1": [
            {"name": "iPhone Duo", "udid": "duo", "isAvailable": False}]}
        self.assertIsNone(choose(devices, "duo", (27, 1, 0)))

    def test_missing_duo_device_can_be_created_from_its_device_type(self):
        devicetypes = [{"name": "iPhone 17 Pro", "identifier": "pro-type"},
                       {"name": "iPhone Duo", "identifier": "duo-type"}]
        runtimes = [{"identifier": "com.apple.CoreSimulator.SimRuntime.iOS-27-0", "isAvailable": True},
                    {"identifier": "com.apple.CoreSimulator.SimRuntime.iOS-27-1", "isAvailable": True}]
        self.assertEqual(creatable(devicetypes, runtimes, "duo", (27, 1, 0)),
                         ("duo-type", "com.apple.CoreSimulator.SimRuntime.iOS-27-1"))
        self.assertIsNone(creatable(devicetypes[:1], runtimes, "duo", (27, 1, 0)))

    def test_created_iphone_prefers_the_usual_model(self):
        devicetypes = [{"name": "iPhone 11", "identifier": "old-type"},
                       {"name": "iPhone 17 Pro", "identifier": "pro-type"}]
        runtimes = [{"identifier": "com.apple.CoreSimulator.SimRuntime.iOS-27-1", "isAvailable": True}]
        self.assertEqual(creatable(devicetypes, runtimes, "iphone", (27, 1, 0))[0], "pro-type")

    def test_maximum_keeps_older_runtimes_and_prefer_picks_a_compatible_model(self):
        devices = dict(DEVICES)
        devices["com.apple.CoreSimulator.SimRuntime.iOS-18-6"] = [
            {"name": "iPhone 16", "udid": "sixteen", "isAvailable": True},
            {"name": "iPhone 16 Pro", "udid": "sixteen-pro", "isAvailable": True},
        ]
        self.assertEqual(choose(devices, "iphone", (18, 0, 0), (18, 99, 99), ["iPhone 16 Pro"]), "sixteen-pro")
        self.assertEqual(choose(devices, "iphone", (18, 0, 0)), "pro")
        devicetypes = [{"name": "iPhone 17 Pro", "identifier": "pro-type"},
                       {"name": "iPhone 16 Pro", "identifier": "sixteen-type"}]
        runtimes = [{"identifier": "com.apple.CoreSimulator.SimRuntime.iOS-18-6", "isAvailable": True},
                    {"identifier": "com.apple.CoreSimulator.SimRuntime.iOS-27-0", "isAvailable": True}]
        self.assertEqual(creatable(devicetypes, runtimes, "iphone", (18, 0, 0), (18, 99, 99), ["iPhone 16 Pro"]),
                         ("sixteen-type", "com.apple.CoreSimulator.SimRuntime.iOS-18-6"))


if __name__ == "__main__":
    unittest.main()
