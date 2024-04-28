# SAMP Translator

![SAMP Translator Logo](https://www.blast.hk/attachments/148318/)

SAMP Translator is an in-game modification for the popular game mode San Andreas Multiplayer (SA-MP). This mod enables real-time translation for various in-game elements, including chat messages, dialogs, 3D texts, text draws, and chat bubbles. It supports a wide array of languages, making it a valuable tool for players from different linguistic backgrounds.

## Supported Languages

- English
- Russian
- Ukrainian
- Belarusian
- Italian
- Bulgarian
- Spanish
- Kazakh
- German
- Polish
- Serbian
- French
- Romanian
- Portuguese
- Lithuanian
- Turkish
- Indonesian

## Dependencies

1. **Move Dependencies to Game Folder:**
   - Locate the `dependencies` folder in the repository.
   - Move all files from the `dependencies` folder into your game folder.

*Note: Ensure all necessary files from the dependencies folder are moved to your game folder for proper functionality. If you are using a different version of SAMP, make sure to download and use the appropriate version of SAMPFUNCS from [Blasthack](https://www.blast.hk).*

## Local server setup
Before you begin, make sure you have Python installed on your system. If not, follow these steps to install Python:

1. **Download Python:** 
   - Visit the [official Python website](https://www.python.org/downloads/) and download the latest version compatible with your operating system.
   - Follow the installation instructions provided on the website.

Once Python is installed, proceed with setting up the local server:

1. **Navigate to the Server Directory:**
   - Open a terminal or command prompt.
   - Change directory to the `server` folder where the server files are located. Use the `cd` command followed by the path to the `server` directory. For example:
     ```
     cd path/to/server
     ```

2. **Install Dependencies:**
   - Inside the `server` directory, there is a file named `requirements.txt`. This file contains a list of dependencies required for the server to run.
   - Install these dependencies using pip, the Python package manager. Run the following command:
     ```
     pip install -r requirements.txt
     ```

3. **Start the Server:**
   - After installing the dependencies, you can start the server by running the `main.py` file.
   - Execute the following command in the terminal:
     ```
     python main.py
     ```

4. **Verify Server Setup:**
   - Once the server is running, you should see a message indicating that the server is running successfully and listening for incoming connections:
   ```
   ======== Running on http://127.0.0.1:9550 ========
   (Press CTRL+C to quit)
   ```

If you see such a message - you can start using the script (console must remain open).

## Activation

To activate the SAMP Translator mod, type the following command in the SA-MP chat: `/translate`

Once activated, the mod will automatically start translating the supported in-game elements based on the selected language.

## Contributing

Contributions to the SAMP Translator mod are welcome! If you have suggestions, bug reports, or want to add support for additional languages, feel free to submit a pull request or create an issue on the GitHub repository.

## Disclaimer

This project is not affiliated with the developers of SA-MP or the game Grand Theft Auto: San Andreas. Use this modification responsibly and adhere to the rules of the game server you are playing on. The developers are not responsible for any negative consequences resulting from the use of this mod.
