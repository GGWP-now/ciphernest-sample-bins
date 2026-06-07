scalaVersion := "3.3.3"

enablePlugins(ScalaNativePlugin)

name := "scala-native-cli"

import scala.scalanative.build._

nativeConfig ~= { c =>
  c.withMode(Mode.releaseFast)
   .withLTO(LTO.none)
}
