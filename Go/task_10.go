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
	sum := 0
	even, odd := 0, 0

	fmt.Scan(&num)
	min, max := num, num

	sum += num

	if num%2 == 0 {
		even++
	} else {
		odd++
	}

	for i := 1; i < n; i++ {
		fmt.Scan(&num)

		sum += num

		if num > max {
			max = num
		}

		if num < min {
			min = num
		}

		if num%2 == 0 {
			even++
		} else {
			odd++
		}
	}

	average := float64(sum) / float64(n)

	fmt.Println("Сумма:", sum)
	fmt.Println("Среднее:", average)
	fmt.Println("Максимум:", max)
	fmt.Println("Минимум:", min)
	fmt.Println("Чётных:", even)
	fmt.Println("Нечётных:", odd)
}
