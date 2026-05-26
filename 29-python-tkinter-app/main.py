import hashlib
import platform
import tkinter as tk
from tkinter import ttk


def calculate() -> None:
    text = input_var.get().strip() or "protector"
    digest = hashlib.sha256(text.encode("utf-8")).hexdigest()
    result_var.set(f"{text} -> {digest[:24]}")


root = tk.Tk()
root.title("Python Tkinter Victim")
root.geometry("420x180")
root.resizable(False, False)

frame = ttk.Frame(root, padding=18)
frame.pack(fill="both", expand=True)

ttk.Label(frame, text="Python Tkinter GUI").pack(anchor="w")
ttk.Label(frame, text=f"{platform.python_implementation()} {platform.python_version()}").pack(anchor="w", pady=(2, 12))

input_var = tk.StringVar(value="matrix-safe")
entry = ttk.Entry(frame, textvariable=input_var)
entry.pack(fill="x")
entry.focus_set()

ttk.Button(frame, text="Hash", command=calculate).pack(anchor="e", pady=10)

result_var = tk.StringVar()
ttk.Label(frame, textvariable=result_var).pack(anchor="w")

calculate()
root.mainloop()
