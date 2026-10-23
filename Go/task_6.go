package main

import "fmt"

func main() {
	var n int
	fmt.Scan(&n)

	positive, negative, zero := 0, 0, 0

	for i := 0; i < n; i++ {
		var num int
		fmt.Scan(&num)

		if num > 0 {
			positive++
		} else if num < 0 {
			negative++
		} else {
			zero++
		}
	}

	fmt.Println("Положительных:", positive)
	fmt.Println("Отрицательных:", negative)
	fmt.Println("Нулей:", zero)
}
