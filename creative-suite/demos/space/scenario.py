"""Native UI test: real pointer and keyboard, no injection."""
import time
from runtime import *


def compose():
    chapter("01 / A blank canvas",
            "Build a six-object still-life from zero.")
    new_project()
    object("Cylinder", "Ink / plinth",
           (-2, -.6, 0), .62, 0, "243F48", .2, .6)
    object("Sphere", "Porcelain / orb",
           (-2, .62, 0), .72, 0, "E9D8B4", .1, .48)

    chapter("02 / The copper hero",
            "Five primitives. One considered palette.")
    object("Torus", "Copper / halo",
           (.15, .23, -.3), 1.22, 35, "B9572B", .72, .3)
    object("Cone", "Petrol / peak",
           (2, -.39, -.6), .8, 0, "176B70", .15, .55)
    object("Box", "Porcelain / block",
           (.65, -.68, 1.65), .55, -22, "E9D8B4", .08, .65)
    check(scene_count() == 5, "Five primitive types arranged")

    chapter("03 / Rhythm & repetition",
            "Duplicate, scale, place; remove the excess.")
    ui.click("Porcelain / orb", "AXStaticText")
    ui.click("Duplicate object")
    object("Sphere", "Copper / bead",
           (-.8, -.77, 1.7), .32, 0,
           "B9572B", .62, .32, add=False)
    ui.click("Duplicate object")
    check(scene_count() == 7, "Duplicate adds a seventh object")
    ui.click("Remove object")
    check(scene_count() == 6, "Remove returns scene to six objects")
    ui.click("Copper / halo", "AXStaticText")
    shot("composition")


def camera_and_delivery():
    chapter("04 / Find the angle",
            "Physical orbit drag, Option-scroll dolly, saved camera.")
    shot("before-orbit")
    ui.drag((850, 660), (815, 670), duration=3,
            during=lambda: shot("orbit-pointer-held"))
    shot("after-orbit-before-dolly")
    ui.dolly(3)
    shot("after-camera")
    ui.click("Use Current Camera for Export")
    ui.wait_for("Camera saved for export")
    check(True, "Native UI confirms camera saved")
    time.sleep(2)

    chapter("05 / Keep the work",
            "Save .devin, close, reopen the same project.")
    data = save_project()
    reopen(data)
    chapter("06 / Deliver",
            "1600 x 1200 render + native SceneKit archive.")
    export("png")
    export("scn")
    chapter("ORBIT / Complete",
            "Six objects. Copper, porcelain, petrol & ink.")
    finish()


if __name__ == "__main__":
    try:
        compose()
        camera_and_delivery()
    except Exception as error:
        fail(error)
        raise
