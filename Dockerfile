FROM apify/actor-python:3.10

# Install dependencies
COPY requirements.txt /tmp/requirements.txt
RUN python3 -m pip install --upgrade pip setuptools wheel
RUN python3 -m pip install -r /tmp/requirements.txt

WORKDIR /src
COPY src/ /src/

# Run the actor
CMD ["python3", "main.py"]
