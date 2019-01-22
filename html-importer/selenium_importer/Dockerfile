FROM selenium/standalone-chrome:2.53.0

EXPOSE 80 5000
USER root
RUN apt-get update

RUN apt-get install -y python-pip python-dev build-essential
RUN pip install --upgrade pip

ADD requirements.txt /
RUN pip install -r /requirements.txt

ADD [".", "/pagedraw-website-importer/"]
WORKDIR /pagedraw-website-importer

ENTRYPOINT ["python"]
CMD ["server.py"]
