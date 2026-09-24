#!/bin/bash
# klik 2x dari Finder buat nyalain backend CampusFlow (buat demo di iPhone).
# terminal ini jangan ditutup selama demo
cd "$(dirname "$0")"
echo "CampusFlow backend jalan di http://$(scutil --get LocalHostName).local:8000"
echo "Tutup jendela ini / tekan Ctrl+C buat matiin server."
.venv/bin/python -m uvicorn app.main:app --host 0.0.0.0 --port 8000
