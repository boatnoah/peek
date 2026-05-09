import Testing
@testable import peek

struct AppDelegateTests {

    @Test func detectsUnitTestEnvironment() {
        #expect(AppDelegate.isRunningUnitTests(environment: [
            "XCTestConfigurationFilePath": "/tmp/peek.xctestconfiguration"
        ]))
    }

    @Test func doesNotTreatNormalEnvironmentAsUnitTests() {
        #expect(!AppDelegate.isRunningUnitTests(environment: [:]))
    }
}
