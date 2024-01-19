import zscaler
import utils
def start_game():
    print("\nNew Game Started!")
    print("You are in charge of securing a network for a large organization.")
    # Example scenario
    scenario_1()
def scenario_1():
    print("\nScenario 1: A new device tries to connect to the network.")
    choice = utils.get_input("Do you: (a) Allow connection, (b) Verify identity, (c) Block connection?", ['a', 'b', 'c'])
    if choice == 'a':
        print("You allowed the connection without verification. Risk of breach increased!")
    elif choice == 'b':
        print("You chose to verify the identity. Good Zero Trust practice!")
        zscaler.verify_identity()
    elif choice == 'c':
        print("You blocked the connection. Safe, but might hinder legitimate work.")
def scenario_2():
    print("\nScenario 2: Anomalous traffic detected from an internal source.")
    choice = utils.get_input("Do you: (a) Ignore, (b) Investigate, (c) Immediately block?", ['a', 'b', 'c'])
    if choice == 'a':
        print("Ignoring the issue could lead to vulnerabilities. Stay alert!")
    elif choice == 'b':
        print("Investigating the traffic. Good decision!")
        zscaler.analyze_traffic()
    elif choice == 'c':
        print("Immediate block might be safe, but could disrupt normal operations.")
def scenario_3():
    print("\nScenario 3: A request to access sensitive data is made from a remote location.")
    choice = utils.get_input("Do you: (a) Grant access, (b) Verify and grant access, (c) Deny access?", ['a', 'b', 'c'])
    if choice == 'a':
        print("Granting access without verification is risky!")
    elif choice == 'b':
        print("You choose to verify first. Implementing Zero Trust effectively!")
        zscaler.data_access_verification()
    elif choice == 'c':
        print("Denying access can be safe, but ensure it doesn't hinder productivity.")
# Modify the start_game function to include these scenarios
def scenario_4():
    print("\nScenario 4: A sudden spike in data transfer is noticed from a high-privilege user.")
    choice = utils.get_input("Do you: (a) Monitor silently, (b) Alert the user, (c) Restrict user access?", ['a', 'b', 'c'])
    if choice == 'a':
        print("Monitoring the situation. Silent observation can be insightful.")
        zscaler.monitor_activity()
    elif choice == 'b':
        print("Alerting the user. Transparency can prevent misunderstandings.")
    elif choice == 'c':
        print("Restricting access as a precaution. Remember to follow up on the case.")
def scenario_5():
    print("\nScenario 5: An external audit requests access to sensitive company data.")
    choice = utils.get_input("Do you: (a) Provide full access, (b) Provide limited access, (c) Deny access?", ['a', 'b', 'c'])
    if choice == 'a':
        print("Providing full access can be risky without proper safeguards.")
    elif choice == 'b':
        print("Providing limited access. A balanced approach.")
        zscaler.limit_data_access()
    elif choice == 'c':
        print("Denying access. Ensure this aligns with legal and company policies.")
def start_game():
    print("\nNew Game Started!")
    print("You are in charge of securing a network for a large organization.")
    scenario_1()
    scenario_2()
    scenario_3()
    scenario_4()
    scenario_5()
