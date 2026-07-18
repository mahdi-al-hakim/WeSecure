/**
 * Displays the list of security services offered by WeSecure.
 * This function dynamically populates the services section on the webpage.
 */
function displaySecurityServices() {
    const services = [
        "Penetration Testing",
        "Vulnerability Assessment",
        "Incident Response",
        "Threat Intelligence",
        "Security Audits",
        "Compliance Management"
    ];
    const servicesContainer = document.getElementById('services-list');
    services.forEach(function (name) {
        const serviceItem = document.createElement('li');
        serviceItem.textContent = name;
        servicesContainer.appendChild(serviceItem);
    });
}
