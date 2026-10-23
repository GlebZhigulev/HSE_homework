package main

import "fmt"

func main() {
	var n int
	fmt.Scan(&n)

	if n <= 0 {
		fmt.Println("N должно быть положительным")
		return
	}

	var num int
	fmt.Scan(&num)

	min, max := num, num

	for i := 1; i < n; i++ {
		fmt.Scan(&num)

		if num > max {
			max = num
		}

		if num < min {
			min = num
		}
	}

	fmt.Println("Максимум:", max)
	fmt.Println("Минимум:", min)
}
