def get_input(prompt, valid_options):
    """ Get user input and validate it. """
    while True:
        user_input = input(prompt + " ").lower()
        if user_input in valid_options:
            return user_input
        else:
            print("Invalid input. Please try again.")
