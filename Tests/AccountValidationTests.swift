import Foundation

@main
enum AccountValidationTests {
    static func main() {
        precondition(AccountValidation.normalizedUsername("  @@Saanvi.I  ") == "saanvi.i")
        precondition(AccountValidation.isValidUsername("saanvi.i"))
        precondition(!AccountValidation.isValidUsername("ab"))
        precondition(AccountValidation.isValidEmail("hello@example.com"))
        precondition(!AccountValidation.isValidEmail("hello@example"))
        precondition(AccountValidation.isStrongPassword("kindness7"))
        precondition(!AccountValidation.isStrongPassword("kindness"))
        precondition(AccountValidation.normalizedWebsite("example.com") == "https://example.com")
        precondition(AccountValidation.normalizedWebsite("javascript:alert(1)") == nil)
        print("AccountValidationTests passed")
    }
}
