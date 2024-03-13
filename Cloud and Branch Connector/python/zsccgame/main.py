import game_logic
def main():
    print("Welcome to the Zscaler Zero Trust Adventure!")
    print("As a network security expert, you will make decisions based on Zero Trust principles.")
    while True:
        game_logic.start_game()
        if input("Play again? (y/n): ").lower() != 'y':
            break
    print("Thank you for playing the Zero Trust Adventure!")
if __name__ == "__main__":
    main()
