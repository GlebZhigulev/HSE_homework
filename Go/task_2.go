package main

import "fmt"

func main() {
	var n int
	fmt.Scan(&n)

	if n > 0 {
		fmt.Println("Положительное")
	} else if n < 0 {
		fmt.Println("Отрицательное")
	} else {
		fmt.Println("Ноль")
	}

	if n%2 == 0 {
		fmt.Println("Чётное")
	} else {
		fmt.Println("Нечётное")
	}

	if n%3 == 0 {
		fmt.Println("Делится на 3")
	} else {
		fmt.Println("Не делится на 3")
	}

	if n%5 == 0 {
		fmt.Println("Делится на 5")
	} else {
		fmt.Println("Не делится на 5")
	}
}
