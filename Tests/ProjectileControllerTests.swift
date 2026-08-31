import Foundation

@inline(__always)
func expectProjectile(_ condition: @autoclosure () -> Bool, _ message: String) {
    if !condition() {
        fputs("FAIL: \(message)\n", stderr)
        exit(1)
    }
}

@main
struct ProjectileControllerTestsMain {
    static func main() {
        var projectile = ProjectileController(
            x: 10,
            velocityX: 100,
            damage: 1,
            lifetime: 1.0
        )

        projectile.update(dt: 0.25)
        expectProjectile(abs(projectile.x - 35) < 0.0001, "Projectile moves horizontally")
        expectProjectile(projectile.isActive, "Projectile remains active before lifetime expires")

        projectile.update(dt: 0.80)
        expectProjectile(!projectile.isActive, "Projectile expires after lifetime")

        var contact = ProjectileController(
            x: 0,
            velocityX: 120,
            damage: 1,
            lifetime: 2.0
        )
        expectProjectile(contact.consumeOnPlayerContact(), "First player contact consumes projectile")
        expectProjectile(!contact.isActive, "Projectile is inactive immediately after player contact")
        expectProjectile(!contact.consumeOnPlayerContact(), "Consumed projectile cannot contact twice")

        var zeroDT = ProjectileController(x: 5, velocityX: 50, damage: 1, lifetime: 1)
        zeroDT.update(dt: -1)
        expectProjectile(zeroDT.x == 5 && zeroDT.isActive, "Negative dt does not advance projectile")

        print("ProjectileControllerTests: PASS")
    }
}
