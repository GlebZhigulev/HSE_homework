package main

import "fmt"

func main() {
	var balance, amount float64
	var choice int

	fmt.Print("Введите баланс: ")
	fmt.Scan(&balance)

	if balance < 0 {
		fmt.Println("Баланс не может быть отрицательным")
		return
	}

	fmt.Println("1. Посмотреть баланс")
	fmt.Println("2. Пополнить баланс")
	fmt.Println("3. Снять средства")

	fmt.Print("Выберите действие: ")
	fmt.Scan(&choice)

	switch choice {
	case 1:
		fmt.Println("Баланс:", balance)

	case 2:
		fmt.Print("Введите сумму пополнения: ")
		fmt.Scan(&amount)

		if amount > 0 {
			balance += amount
			fmt.Println("Новый баланс:", balance)
		} else {
			fmt.Println("Некорректная сумма")
		}

	case 3:
		fmt.Print("Введите сумму снятия: ")
		fmt.Scan(&amount)

		if amount <= 0 {
			fmt.Println("Некорректная сумма")
		} else if amount > balance {
			fmt.Println("Недостаточно средств")
		} else {
			balance -= amount
			fmt.Println("Новый баланс:", balance)
		}

	default:
		fmt.Println("Неизвестная операция")
	}
}
