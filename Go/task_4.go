package main

import "fmt"

func printTable(n int) {
	for i := 1; i <= 10; i++ {
		fmt.Printf("%d * %d = %d\n", n, i, n*i)
	}
}

func main() {
	var n int
	fmt.Scan(&n)

	printTable(n)
}
