// Scala Native CLI Victim -- Prime Sieve + Fibonacci
// Build: sbt nativeLink   (emits target/scala-3.3.3/scala-native-cli-out[.exe])
import java.io.{File, PrintWriter}
import scala.io.Source
import scala.util.Try

object Main {
  def fib(n: Int): Long = {
    if (n <= 1) return n.toLong
    var a = 0L
    var b = 1L
    var i = 2
    while (i <= n) {
      val t = a + b
      a = b
      b = t
      i += 1
    }
    b
  }

  def main(args: Array[String]): Unit = {
    var limit = 100
    if (args.nonEmpty) {
      Try(args(0).toInt).foreach(v => if (v >= 10) limit = v)
    }

    println("Scala Native CLI Victim -- Prime Sieve + Fibonacci")
    println(s"Limit: $limit")
    println("")
    println(s"Fibonacci($limit) = ${fib(limit)}")

    val buf = Array.fill(limit + 1)(false)
    var i = 2
    while (i * i <= limit) {
      if (!buf(i)) {
        var j = i * i
        while (j <= limit) {
          buf(j) = true
          j += i
        }
      }
      i += 1
    }

    var count = 0
    var largest = 0
    var hash = 5381L
    var n = 2
    while (n <= limit) {
      if (!buf(n)) {
        count += 1
        largest = n
        hash = (hash << 5) + hash + n.toLong
      }
      n += 1
    }

    println(s"Primes up to $limit: $count")
    if (count > 0) println(s"Largest prime: $largest")

    val fname = "scala_native_cli_test.txt"
    Try {
      val pw = new PrintWriter(new File(fname))
      pw.write(s"Scala Native CLI Victim -- $count primes up to $limit\n")
      pw.close()
      val content = Source.fromFile(fname).mkString
      print(s"File I/O: $content")
      new File(fname).delete()
    }

    println(f"Checksum: 0x$hash%016X")
  }
}
