package main

import "fmt"

func isPrime(n int) bool {
	if n < 2 {
		return false
	}

	for i := 2; i <= n/i; i++ {
		if n%i == 0 {
			return false
		}
	}

	return true
}

func main() {
	var n int
	fmt.Scan(&n)

	if isPrime(n) {
		fmt.Println("Простое число")
	} else {
		fmt.Println("Не простое число")
	}
}
