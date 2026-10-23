package main

import "fmt"

func main() {
	var n int
	fmt.Scan(&n)

	sum := 0

	for i := 1; i <= n; i++ {
		if i%2 == 0 && i%3 == 0 {
			sum += i
		}
	}

	fmt.Println("Сумма:", sum)
}
