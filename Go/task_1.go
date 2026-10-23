package main

import "fmt"

func main() {
	var a, b float64
	var operation string

	fmt.Scan(&a, &b, &operation)

	switch operation {
	case "+":
		fmt.Println(a + b)
	case "-":
		fmt.Println(a - b)
	case "*":
		fmt.Println(a * b)
	case "/":
		if b == 0 {
			fmt.Println("Ошибка: деление на ноль")
		} else {
			fmt.Println(a / b)
		}
	default:
		fmt.Println("Неизвестная операция")
	}
}
