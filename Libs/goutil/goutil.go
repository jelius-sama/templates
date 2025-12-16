package main

import (
    "C"
    "fmt"
)

//export Test
func Test() {
    fmt.Println("Hello from Go Util!")
}

func main() {}

