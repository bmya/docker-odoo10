FROM python:2.7.12
MAINTAINER Blanco Martín & Asociados. <info@blancomartin.cl>

USER root

# Generate locale (es_AR for right odoo es_AR language config, and C.UTF-8 for postgres and general locale data)
ENV DEBIAN_FRONTEND noninteractive
RUN apt-get update -qq && apt-get install -y locales -qq
RUN echo 'es_AR.UTF-8 UTF-8' >> /etc/locale.gen && locale-gen
RUN echo 'es_CL.UTF-8 UTF-8' >> /etc/locale.gen && locale-gen
RUN echo 'es_US.UTF-8 UTF-8' >> /etc/locale.gen && locale-gen
RUN echo 'C.UTF-8 UTF-8' >> /etc/locale.gen && locale-gen
RUN dpkg-reconfigure locales && /usr/sbin/update-locale LANG=C.UTF-8
ENV LANG C.UTF-8
ENV LANGUAGE C.UTF-8
ENV LC_ALL C.UTF-8

# added from odoo-bmya build
RUN apt-get update && apt-get install -y git vim
RUN apt-get install -y ghostscript

# webservices dependencies
RUN pip install urllib3

# letsencrypt dependencies:
RUN pip install acme-tiny
RUN pip install IPy

# woocommerce dependency
RUN pip install woocommerce

# used by many pip packages
RUN apt-get install -y python-dev freetds-dev

# Freetds an pymssql added in conjunction
RUN pip install pymssql

# odoo-extra
RUN apt-get install -y python-matplotlib font-manager

# odoo argentina (nuevo modulo de FE).
RUN apt-get install -y swig libffi-dev libssl-dev python-m2crypto python-httplib2 mercurial
# NECESATIOS PARA SIGNXML
RUN apt-get install -y libxml2-dev libxslt-dev python-dev lib32z1-dev liblz-dev

RUN pip install geopy==0.95.1 BeautifulSoup pyOpenSSL suds cryptography certifi

# odoo bmya cambiado de orden (antes o despues de odoo argentina)
# to be removed when we remove crypto
RUN apt-get install -y swig libssl-dev
# to be removed when we remove crypto
RUN pip install suds

# Agregado por Daniel Blanco para ver si soluciona el problema de la falta de la biblioteca pysimplesoap
# RUN git clone https://github.com/pysimplesoap/pysimplesoap.git
# WORKDIR /pysimplesoap/
# RUN python setup.py install

# instala pyafip desde google code usando mercurial
# M2Crypto suponemos que no haria falta ahora
# RUN hg clone https://code.google.com/p/pyafipws
RUN git clone https://github.com/bmya/pyafipws.git
WORKDIR /pyafipws/
# ADD ./requirements.txt /pyafipws/
RUN pip install -r requirements.txt
RUN python setup.py install
RUN chmod 777 -R /usr/local/lib/python2.7/site-packages/pyafipws/

# RUN git clone https://github.com/reingart/pyafipws.git
# WORKDIR /pyafipws/
# RUN python setup.py install
# RUN chmod 777 -R /usr/local/lib/python2.7/site-packages/pyafipws/


# odoo etl, infra and others
RUN pip install openerp-client-lib fabric erppeek fabtools

# dte implementation
RUN pip install xmltodict
RUN pip install dicttoxml
RUN pip install elaphe
# RUN pip install hashlib
RUN pip install cchardet
RUN pip install lxml
RUN pip install signxml

RUN pip install pysftp

# oca reports
RUN pip install xlwt

# odoo kineses
RUN pip install xlrd

# add user with the same user id as in core odoo package
# unfortunately python comes with group 107 already defined so I used www-data as group
RUN useradd -m -d /var/lib/odoo -s /bin/false -u 104 -g 33 odoo

# Install some deps, lessc and less-plugin-clean-css, and wkhtmltopdf
RUN set -x; \
        apt-get update \
        && apt-get install -y --no-install-recommends \
            ca-certificates \
            curl \
        && curl -o wkhtmltox.deb -SL http://nightly.odoo.com/extra/wkhtmltox-0.12.1.2_linux-jessie-amd64.deb \
        && echo '40e8b906de658a2221b15e4e8cd82565a47d7ee8 wkhtmltox.deb' | sha1sum -c - \
        && dpkg --force-depends -i wkhtmltox.deb \
        && apt-get -y install -f --no-install-recommends \
        && apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false -o APT::AutoRemove::SuggestsImportant=false npm \
        && rm -rf /var/lib/apt/lists/* wkhtmltox.deb

# support for Postgresql9.5
RUN echo "deb http://apt.postgresql.org/pub/repos/apt/ jessie-pgdg main 9.6" > /etc/apt/sources.list.d/postgresql.list \
        && wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | apt-key add - \
        && apt-get update \
        && apt-get upgrade -y postgresql-common \
        && apt-get upgrade -y postgresql-client

# install newer node and lessc (mostly for less compatibility)
RUN set -x; \
        apt-get install -y nodejs npm

RUN npm install -g less \
    && npm install -g less-plugin-clean-css \
    && ln -s `which nodejs` /bin/node \
    && ln -s `which lessc` /bin/lessc

# python python-minimal python2.7 python2.7-minimal
RUN apt-get purge -y python.*

# Install Odoo
ENV ODOO_VERSION 10.0
ENV ODOO_RELEASE 20161011
RUN set -x; \
        apt-get install -y libsasl2-dev libldap2-dev libssl-dev gcc \
        && curl -o odoo.tar.gz -SL https://nightly.odoo.com/${ODOO_VERSION}/nightly/src/odoo_${ODOO_VERSION}.${ODOO_RELEASE}.tar.gz \
        && tar xzf odoo.tar.gz \
        && cd odoo-${ODOO_VERSION}-${ODOO_RELEASE} \
        && pip install . \
        && cd .. && rm -rf ./odoo* \
        && pip install --upgrade \
            cryptography \
            inotify \
            watchdog \
            psycogreen \
            psycopg2 \
            gevent \
            pyinotify \
            newrelic \
            flanker \
        && apt-get purge -y \
            gcc \
            libsasl2-dev \
            libldap2-dev \
            libssl-dev


# Copy entrypoint script and Odoo configuration file
COPY ./entrypoint.sh /
COPY ./odoo.conf /etc/odoo/
RUN chown odoo /etc/odoo/odoo.conf

# Mount /var/lib/odoo to allow restoring filestore and /mnt/extra-addons for users addons
RUN mkdir -p /mnt/extra-addons \
        && chown -R odoo /mnt/extra-addons
VOLUME ["/var/lib/odoo", "/mnt/extra-addons"]

# Expose Odoo services
EXPOSE 8069 8071

# Set the default config file - NOTE this is still used in odoo/tools/config.py in v10
ENV OPENERP_SERVER /etc/odoo/odoo.conf

# Set default user when running the container
USER odoo

ENTRYPOINT ["/entrypoint.sh"]
CMD ["odoo"]